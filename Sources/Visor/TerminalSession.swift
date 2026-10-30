import AppKit
import Darwin
import PTYShim

enum TerminalSessionKind: Equatable {
    case shell
    case ssh(UUID)
}

final class TerminalSession {
    let id = UUID()
    private(set) var title: String
    private let initialTitle: String
    let kind: TerminalSessionKind
    private(set) var processID: pid_t = 0
    private(set) var masterFD: Int32 = -1
    private(set) var transcript = Data()
    var onOutput: ((Data) -> Void)?
    var onExit: (() -> Void)?
    var onTitleChange: (() -> Void)?

    private var readSource: DispatchSourceRead?
    private var pendingCommand = ""
    private var escapeSequenceState = 0
    private var sshTitleStack: [String] = []
    private var sshForegroundMonitor: DispatchSourceTimer?
    private var observedSSHForegroundProcess = false
    private var foregroundMonitorAttempts = 0

    init(title: String, kind: TerminalSessionKind = .shell, command: [String]? = nil) throws {
        self.title = title
        self.initialTitle = title
        self.kind = kind
        try start(command: command)
    }

    private func start(command: [String]?) throws {
        var master: Int32 = -1
        var size = winsize(ws_row: 30, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0)
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let args = command ?? [shell, "-l"]
        let executable = args[0]
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["TERM_PROGRAM"] = "Visor"
        environment["TERM_PROGRAM_VERSION"] = "0.8.0"

        var cArguments: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) } + [nil]
        var cEnvironment: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            cArguments.compactMap { $0 }.forEach { free($0) }
            cEnvironment.compactMap { $0 }.forEach { free($0) }
        }

        var pid: pid_t = 0
        let spawnResult = executable.withCString { executablePath in
            cArguments.withUnsafeMutableBufferPointer { argv in
                cEnvironment.withUnsafeMutableBufferPointer { envp in
                    visor_spawn_pty(executablePath, argv.baseAddress!, envp.baseAddress!, &master, &pid, &size)
                }
            }
        }
        guard spawnResult == 0 else {
            throw POSIXError(.init(rawValue: spawnResult) ?? .EIO)
        }

        masterFD = master
        processID = pid

        let source = DispatchSource.makeReadSource(fileDescriptor: master, queue: .global(qos: .userInteractive))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var buffer = [UInt8](repeating: 0, count: 8192)
            let count = Darwin.read(self.masterFD, &buffer, buffer.count)
            if count > 0 {
                let data = Data(buffer.prefix(count))
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.record(data)
                    self.onOutput?(data)
                }
            } else if count == 0 || errno == EIO {
                DispatchQueue.main.async { [weak self] in self?.onExit?() }
                self.readSource?.cancel()
            }
        }
        source.setCancelHandler { close(master) }
        readSource = source
        source.resume()
    }

    private func record(_ data: Data) {
        transcript.append(data)
        let maximumBytes = 8 * 1024 * 1024
        let retainedBytes = 6 * 1024 * 1024
        if transcript.count > maximumBytes {
            transcript.removeFirst(transcript.count - retainedBytes)
        }
    }

    func send(_ data: Data) {
        guard masterFD >= 0 else { return }
        trackCommandForSSH(in: data)
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(masterFD, base.advanced(by: offset), bytes.count - offset)
                if written > 0 {
                    offset += written
                } else if written < 0, errno == EINTR {
                    continue
                } else {
                    break
                }
            }
        }
    }

    private func trackCommandForSSH(in data: Data) {
        guard kind == .shell else { return }

        for byte in data {
            if byte == 0x1b {
                escapeSequenceState = 1
                continue
            }
            if escapeSequenceState == 1 {
                escapeSequenceState = (byte == 0x5b || byte == 0x5d) ? 2 : 0
                continue
            }
            if escapeSequenceState == 2 {
                if (0x40...0x7e).contains(byte) { escapeSequenceState = 0 }
                continue
            }

            switch byte {
            case 0x0a, 0x0d:
                let command = pendingCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                if let host = SSHCommandParser.host(from: command) {
                    sshTitleStack.append(title)
                    updateTitle(host)
                    beginMonitoringSSHForegroundProcess()
                } else if isRemoteExitCommand(command) {
                    restorePreviousSSHTitle()
                }
                pendingCommand = ""
            case 0x03, 0x15:
                pendingCommand = ""
            case 0x04:
                restorePreviousSSHTitle()
            case 0x08, 0x7f:
                if !pendingCommand.isEmpty { pendingCommand.removeLast() }
            case 0x20...0x7e:
                pendingCommand.append(Character(UnicodeScalar(byte)))
            default:
                break
            }
        }
    }

    private func isRemoteExitCommand(_ command: String) -> Bool {
        guard let firstWord = command.split(whereSeparator: { $0.isWhitespace }).first else { return false }
        return firstWord == "exit" || firstWord == "logout"
    }

    private func updateTitle(_ newTitle: String) {
        guard title != newTitle else { return }
        title = newTitle
        onTitleChange?()
    }

    private func restorePreviousSSHTitle() {
        guard let previousTitle = sshTitleStack.popLast() else { return }
        updateTitle(previousTitle)
        if sshTitleStack.isEmpty { stopMonitoringSSHForegroundProcess() }
    }

    private func beginMonitoringSSHForegroundProcess() {
        guard sshForegroundMonitor == nil else { return }
        observedSSHForegroundProcess = false
        foregroundMonitorAttempts = 0

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in self?.checkSSHForegroundProcess() }
        sshForegroundMonitor = timer
        timer.resume()
    }

    private func checkSSHForegroundProcess() {
        guard masterFD >= 0, processID > 0 else {
            restoreInitialTitleAfterSSH()
            return
        }

        foregroundMonitorAttempts += 1
        let foregroundProcessGroup = tcgetpgrp(masterFD)
        if foregroundProcessGroup > 0, foregroundProcessGroup != processID {
            observedSSHForegroundProcess = true
            return
        }

        if observedSSHForegroundProcess || foregroundMonitorAttempts >= 20 {
            restoreInitialTitleAfterSSH()
        }
    }

    private func restoreInitialTitleAfterSSH() {
        let restoredTitle = sshTitleStack.first ?? initialTitle
        sshTitleStack.removeAll()
        updateTitle(restoredTitle)
        stopMonitoringSSHForegroundProcess()
    }

    private func stopMonitoringSSHForegroundProcess() {
        sshForegroundMonitor?.cancel()
        sshForegroundMonitor = nil
        observedSSHForegroundProcess = false
        foregroundMonitorAttempts = 0
    }

    func resize(rows: UInt16, columns: UInt16) {
        guard masterFD >= 0 else { return }
        var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFD, TIOCSWINSZ, &size)
        if processID > 0 { kill(processID, SIGWINCH) }
    }

    func terminate() {
        stopMonitoringSSHForegroundProcess()
        if processID > 0 {
            kill(processID, SIGHUP)
            processID = 0
        }
        readSource?.cancel()
        readSource = nil
        masterFD = -1
    }

    deinit { terminate() }
}
