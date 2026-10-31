import AppKit
import QuartzCore

private extension NSScreen {
    var visorDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var visorPersistentIdentifier: String? {
        guard let displayID = visorDisplayID else { return nil }
        let vendor = CGDisplayVendorNumber(displayID)
        let model = CGDisplayModelNumber(displayID)
        let serial = CGDisplaySerialNumber(displayID)
        return serial == 0
            ? "display-\(displayID)-\(vendor)-\(model)"
            : "display-\(vendor)-\(model)-\(serial)"
    }
}

final class VisorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ResizeHandle: NSView {
    var onDrag: ((CGFloat) -> Void)?
    private var initialY: CGFloat = 0

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) { initialY = NSEvent.mouseLocation.y }
    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation.y
        onDrag?(initialY - current)
        initialY = current
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: bounds.midX - 32, y: 2, width: 64, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
    }
}

final class VisorWindowController: NSWindowController {
    var onShortcutChange: ((KeyboardShortcut) -> Result<Void, Error>)?
    private let settings = VisorSettings.shared
    private let profileStore = SSHProfileStore.shared
    private let root = NSView()
    private let tabChrome = NSView()
    private let tabBar = NSStackView()
    private let bookmarkChrome = NSView()
    private let bookmarkBar = NSStackView()
    private let terminalContainer = NSView()
    private var sessions: [TerminalSession] = []
    private var terminalViews: [UUID: TerminalWebView] = [:]
    private var selectedIndex = 0
    private var isVisible = false
    private var animationGeneration = 0
    private let slideAnimationKey = "visor.contentSlide"

    init() {
        let panel = VisorPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        configureWindow(panel)
        configureInterface()
        rebuildBookmarks()
        addShell()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureWindow(_ panel: NSPanel) {
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        positionWindow()
    }

    private func configureInterface() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.masksToBounds = true
        root.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.black.withAlphaComponent(settings.opacity).cgColor
        content.addSubview(root)

        tabBar.orientation = .horizontal
        tabBar.alignment = .centerY
        tabBar.spacing = 5
        tabBar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabChrome.translatesAutoresizingMaskIntoConstraints = false
        tabChrome.wantsLayer = true
        tabChrome.layer?.backgroundColor = NSColor(calibratedWhite: 0.075, alpha: 0.97).cgColor
        root.addSubview(tabChrome)
        tabChrome.addSubview(tabBar)

        bookmarkBar.orientation = .horizontal
        bookmarkBar.alignment = .centerY
        bookmarkBar.spacing = 6
        bookmarkBar.edgeInsets = NSEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        bookmarkBar.translatesAutoresizingMaskIntoConstraints = false
        bookmarkChrome.translatesAutoresizingMaskIntoConstraints = false
        bookmarkChrome.wantsLayer = true
        bookmarkChrome.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 0.97).cgColor
        bookmarkChrome.layer?.borderColor = NSColor(calibratedWhite: 0.18, alpha: 0.65).cgColor
        bookmarkChrome.layer?.borderWidth = 0.5
        root.addSubview(bookmarkChrome)
        bookmarkChrome.addSubview(bookmarkBar)

        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(terminalContainer)

        let handle = ResizeHandle()
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.onDrag = { [weak self] delta in self?.resizeHeight(by: delta) }
        root.addSubview(handle)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            tabChrome.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            tabChrome.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            tabChrome.topAnchor.constraint(equalTo: root.topAnchor),
            tabChrome.heightAnchor.constraint(equalToConstant: 42),
            tabBar.leadingAnchor.constraint(equalTo: tabChrome.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: tabChrome.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: tabChrome.topAnchor),
            tabBar.bottomAnchor.constraint(equalTo: tabChrome.bottomAnchor),
            bookmarkChrome.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bookmarkChrome.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bookmarkChrome.topAnchor.constraint(equalTo: tabChrome.bottomAnchor),
            bookmarkChrome.heightAnchor.constraint(equalToConstant: 34),
            bookmarkBar.leadingAnchor.constraint(equalTo: bookmarkChrome.leadingAnchor),
            bookmarkBar.trailingAnchor.constraint(equalTo: bookmarkChrome.trailingAnchor),
            bookmarkBar.topAnchor.constraint(equalTo: bookmarkChrome.topAnchor),
            bookmarkBar.bottomAnchor.constraint(equalTo: bookmarkChrome.bottomAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            terminalContainer.topAnchor.constraint(equalTo: bookmarkChrome.bottomAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: handle.topAnchor),
            handle.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            handle.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            handle.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            handle.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    private var activeSession: TerminalSession? {
        sessions.indices.contains(selectedIndex) ? sessions[selectedIndex] : nil
    }

    private var activeTerminalView: TerminalWebView? {
        activeSession.flatMap { terminalViews[$0.id] }
    }

    func toggle() { isVisible ? hide() : show() }

    func show(animated: Bool = true) {
        guard let window, let visibleFrame = panelFrame(preferCurrentScreen: false) else { return }

        animationGeneration += 1
        let generation = animationGeneration
        let wasVisible = window.isVisible
        isVisible = true

        window.setFrame(visibleFrame, display: false)
        if !wasVisible { setContentTranslation(visibleFrame.height) }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        activeTerminalView?.focus()

        guard animated else {
            window.setFrame(visibleFrame, display: true)
            activeTerminalView?.fit()
            return
        }

        animateContent(to: 0, fullDistance: visibleFrame.height, duration: 0.42) { [weak self, weak window] in
            guard let self, let window,
                  self.animationGeneration == generation,
                  self.isVisible else { return }
            window.makeKey()
            self.activeTerminalView?.focus()
            self.activeTerminalView?.fit()
        }
    }

    func hide(animated: Bool = true) {
        guard isVisible, let window else { return }

        animationGeneration += 1
        let generation = animationGeneration
        isVisible = false

        guard animated, let visibleFrame = panelFrame() else {
            window.orderOut(nil)
            return
        }

        animateContent(to: visibleFrame.height, fullDistance: visibleFrame.height, duration: 0.34) { [weak self, weak window] in
            guard let self, let window,
                  self.animationGeneration == generation,
                  !self.isVisible else { return }
            window.orderOut(nil)
            self.setContentTranslation(0)
        }
    }

    private func setContentTranslation(_ value: CGFloat) {
        guard let layer = root.layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setAffineTransform(CGAffineTransform(translationX: 0, y: value))
        CATransaction.commit()
    }

    private func animateContent(
        to destination: CGFloat,
        fullDistance: CGFloat,
        duration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        guard let layer = root.layer else {
            completion()
            return
        }

        let presentationValue = layer.presentation()?.value(forKeyPath: "transform.translation.y") as? NSNumber
        let modelValue = layer.value(forKeyPath: "transform.translation.y") as? NSNumber
        let current = CGFloat((presentationValue ?? modelValue)?.doubleValue ?? 0)
        layer.removeAnimation(forKey: slideAnimationKey)
        setContentTranslation(destination)

        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = current
        animation.toValue = destination
        let distanceRatio = fullDistance > 0 ? abs(destination - current) / fullDistance : 1
        animation.duration = max(0.08, duration * Double(distanceRatio))
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        layer.add(animation, forKey: slideAnimationKey)
        CATransaction.commit()
    }


    private func positionWindow() {
        guard let frame = panelFrame() else { return }
        window?.setFrame(frame, display: true)
    }

    private func panelFrame(preferCurrentScreen: Bool = true) -> NSRect? {
        guard let screenFrame = panelScreen(preferCurrentScreen: preferCurrentScreen)?.visibleFrame else { return nil }
        return PanelGeometry.visibleFrame(in: screenFrame, requestedHeight: settings.panelHeight)
    }

    private func panelScreen(preferCurrentScreen: Bool) -> NSScreen? {
        if let identifier = settings.lockedScreenIdentifier,
           let lockedScreen = NSScreen.screens.first(where: { $0.visorPersistentIdentifier == identifier }) {
            return lockedScreen
        }
        if preferCurrentScreen, isVisible, let currentScreen = window?.screen {
            return currentScreen
        }
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func resizeHeight(by delta: CGFloat) {
        settings.panelHeight = min(max(settings.panelHeight + delta, 220), (NSScreen.main?.visibleFrame.height ?? 900) * 0.9)
        positionWindow()
        activeTerminalView?.fit()
    }

    @objc private func addShell() {
        do {
            let session = try TerminalSession(title: "shell \(sessions.count + 1)")
            bind(session)
            sessions.append(session)
            selectedIndex = sessions.count - 1
            rebuildTabs()
            selectSession(selectedIndex)
        } catch {
            showError("Could not start a shell: \(error.localizedDescription)")
        }
    }

    private func startSSH(_ profile: SSHProfile) {
        do {
            let session = try TerminalSession(
                title: profile.displayName,
                kind: .ssh(profile.id),
                command: profile.command
            )
            bind(session)
            sessions.append(session)
            selectedIndex = sessions.count - 1
            rebuildTabs()
            selectSession(selectedIndex)
        } catch {
            showError("Could not start SSH: \(error.localizedDescription)")
        }
    }

    private func startUtility(title: String, command: [String]) {
        do {
            let session = try TerminalSession(title: title, command: command)
            bind(session)
            sessions.append(session)
            selectedIndex = sessions.count - 1
            rebuildTabs()
            selectSession(selectedIndex)
        } catch {
            showError("Could not start \(title.lowercased()): \(error.localizedDescription)")
        }
    }

    private func bind(_ session: TerminalSession) {
        let terminal = TerminalWebView()
        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminal.isHidden = true
        terminal.onInput = { [weak session] data in session?.send(data) }
        terminal.onResize = { [weak session] rows, columns in session?.resize(rows: rows, columns: columns) }
        terminalContainer.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: terminalContainer.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: terminalContainer.bottomAnchor)
        ])
        terminalViews[session.id] = terminal

        session.onOutput = { [weak terminal] data in terminal?.write(data) }
        session.onExit = { [weak self] in self?.rebuildTabs() }
        session.onTitleChange = { [weak self] in self?.rebuildTabs() }
    }

    @objc private func selectTab(_ sender: NSButton) { selectSession(sender.tag) }

    private func selectSession(_ index: Int) {
        guard sessions.indices.contains(index) else { return }
        selectedIndex = index
        for (sessionID, terminal) in terminalViews {
            terminal.isHidden = sessionID != sessions[index].id
        }
        rebuildTabs()
        activeTerminalView?.focus()
        activeTerminalView?.fit()
    }

    @objc private func closeActiveTab() {
        closeSession(at: selectedIndex)
    }

    @objc private func closeTab(_ sender: NSButton) {
        closeSession(at: sender.tag)
    }

    private func closeSession(at index: Int) {
        guard sessions.indices.contains(index) else { return }
        let session = sessions.remove(at: index)
        terminalViews.removeValue(forKey: session.id)?.removeFromSuperview()
        session.terminate()
        if sessions.isEmpty {
            addShell()
            return
        }
        selectedIndex = min(selectedIndex, sessions.count - 1)
        selectSession(selectedIndex)
    }

    private func rebuildTabs() {
        tabBar.arrangedSubviews.forEach { view in tabBar.removeArrangedSubview(view); view.removeFromSuperview() }
        let settingsButton = ChromeIconButton(symbol: "slider.horizontal.3", help: "Settings", target: self, action: #selector(showSettings(_:)))
        tabBar.addArrangedSubview(settingsButton)
        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(calibratedWhite: 0.25, alpha: 0.7).cgColor
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 18).isActive = true
        tabBar.addArrangedSubview(divider)
        for (index, session) in sessions.enumerated() {
            tabBar.addArrangedSubview(TabChipView(
                title: session.title,
                symbol: session.kind == .shell ? nil : "link",
                index: index,
                selected: index == selectedIndex,
                target: self,
                selectAction: #selector(selectTab(_:)),
                closeAction: #selector(closeTab(_:))
            ))
        }
        tabBar.addArrangedSubview(ChromeIconButton(symbol: "plus", help: "New shell tab", target: self, action: #selector(addShell)))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tabBar.addArrangedSubview(spacer)
    }

    private func rebuildBookmarks() {
        bookmarkBar.arrangedSubviews.forEach { view in
            bookmarkBar.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let label = NSTextField(labelWithString: "SSH")
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 0.42, alpha: 1)
        bookmarkBar.addArrangedSubview(label)

        for profile in profileStore.profiles {
            let button = SSHBookmarkButton(profile: profile, target: self, action: #selector(connectBookmark(_:)))
            button.menu = profileMenu(for: profile)
            bookmarkBar.addArrangedSubview(button)
        }

        bookmarkBar.addArrangedSubview(ChromeIconButton(
            symbol: "plus",
            help: "New SSH connection",
            target: self,
            action: #selector(addSSHProfile),
            size: 24
        ))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bookmarkBar.addArrangedSubview(spacer)
    }

    @objc private func connectBookmark(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue,
              let id = UUID(uuidString: value),
              let profile = profileStore.profile(id: id) else { return }
        startSSH(profile)
    }

    @objc private func addSSHProfile() {
        guard let profile = SSHProfileEditor.present() else { return }
        profileStore.save(profile)
        rebuildBookmarks()
        startSSH(profile)
    }

    @objc private func connectProfile(_ sender: NSMenuItem) {
        guard let profile = profile(from: sender) else { return }
        startSSH(profile)
    }

    @objc private func editProfile(_ sender: NSMenuItem) {
        guard let oldProfile = profile(from: sender),
              let updated = SSHProfileEditor.present(existing: oldProfile) else { return }
        profileStore.save(updated)
        rebuildBookmarks()
        rebuildTabs()
    }

    @objc private func chooseIdentityFile(_ sender: NSMenuItem) {
        guard var profile = profile(from: sender) else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose SSH Private Key"
        panel.message = "Choose the private key. Its matching public key should be beside it with a .pub extension."
        panel.prompt = "Choose Key"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh", isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            profile.identityFile = SSHKeySupport.storablePath(url.path)
            profileStore.save(profile)
            rebuildBookmarks()
        }
    }

    @objc private func generateIdentityFile(_ sender: NSMenuItem) {
        guard var profile = profile(from: sender) else { return }
        let sshDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: sshDirectory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sshDirectory.path)
        } catch {
            showError("Could not prepare ~/.ssh: \(error.localizedDescription)")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Generate Ed25519 SSH Key"
        panel.message = "Choose where to store the private key. The public key will use the same name with .pub added."
        panel.prompt = "Generate Key"
        panel.nameFieldStringValue = "id_ed25519"
        panel.directoryURL = sshDirectory
        panel.canCreateDirectories = true
        panel.showsHiddenFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let publicURL = URL(fileURLWithPath: url.path + ".pub")
        guard !FileManager.default.fileExists(atPath: url.path),
              !FileManager.default.fileExists(atPath: publicURL.path) else {
            showError("A key already exists at that location. Choose the existing private key instead, or use a different name.")
            return
        }

        profile.identityFile = SSHKeySupport.storablePath(url.path)
        profileStore.save(profile)
        rebuildBookmarks()
        startUtility(title: "Create SSH key", command: SSHKeySupport.generationCommand(path: url.path))
    }

    @objc private func installIdentityFile(_ sender: NSMenuItem) {
        guard let profile = profile(from: sender) else { return }
        do {
            let publicKey = try SSHKeySupport.readPublicKey(for: profile)
            let alert = NSAlert()
            alert.messageText = "Install Key on “\(profile.displayName)” ?"
            alert.informativeText = "Visor will connect to \(profile.destination) and add the selected public key to ~/.ssh/authorized_keys if it is not already present. SSH may ask for the server password."
            alert.addButton(withTitle: "Install Key")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            startUtility(
                title: "Install key: \(profile.displayName)",
                command: SSHKeySupport.installCommand(profile: profile, publicKey: publicKey)
            )
        } catch {
            showError(error.localizedDescription)
        }
    }

    @objc private func addIdentityFileToKeychain(_ sender: NSMenuItem) {
        guard let profile = profile(from: sender) else { return }
        do {
            _ = try SSHKeySupport.validatePrivateKey(for: profile)
            startUtility(
                title: "Remember key: \(profile.displayName)",
                command: try SSHKeySupport.keychainCommand(profile: profile)
            )
        } catch {
            showError(error.localizedDescription)
        }
    }

    @objc private func testIdentityFile(_ sender: NSMenuItem) {
        guard let profile = profile(from: sender) else { return }
        do {
            _ = try SSHKeySupport.validatePrivateKey(for: profile)
            startUtility(
                title: "Test key: \(profile.displayName)",
                command: SSHKeySupport.testCommand(profile: profile)
            )
        } catch {
            showError(error.localizedDescription)
        }
    }

    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let profile = profile(from: sender) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete “\(profile.displayName)”?"
        alert.informativeText = "Open SSH tabs will keep running. This only removes the saved connection."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        profileStore.delete(id: profile.id)
        rebuildBookmarks()
    }

    @objc private func reconnectActiveSSH() {
        guard case let .ssh(id)? = activeSession?.kind,
              let profile = profileStore.profile(id: id) else { return }
        startSSH(profile)
    }

    private func profile(from sender: NSMenuItem) -> SSHProfile? {
        guard let value = sender.representedObject as? String,
              let id = UUID(uuidString: value) else { return nil }
        return profileStore.profile(id: id)
    }

    private func profileMenu(for profile: SSHProfile) -> NSMenu {
        let menu = NSMenu(title: profile.displayName)
        menu.addItem(profileMenuItem("Connect", action: #selector(connectProfile(_:)), profile: profile))
        menu.addItem(.separator())
        menu.addItem(profileMenuItem("Choose Identity File…", action: #selector(chooseIdentityFile(_:)), profile: profile))
        menu.addItem(profileMenuItem("Generate SSH Key…", action: #selector(generateIdentityFile(_:)), profile: profile))
        menu.addItem(profileMenuItem("Add Key to macOS Keychain…", action: #selector(addIdentityFileToKeychain(_:)), profile: profile))
        menu.addItem(profileMenuItem("Install Public Key…", action: #selector(installIdentityFile(_:)), profile: profile))
        menu.addItem(profileMenuItem("Test Key Login", action: #selector(testIdentityFile(_:)), profile: profile))
        menu.addItem(.separator())
        menu.addItem(profileMenuItem("Edit…", action: #selector(editProfile(_:)), profile: profile))
        menu.addItem(.separator())
        menu.addItem(profileMenuItem("Delete", action: #selector(deleteProfile(_:)), profile: profile))
        return menu
    }

    private func profileMenuItem(_ title: String, action: Selector, profile: SSHProfile) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = profile.id.uuidString
        return item
    }

    @objc private func showSettings(_ sender: NSButton) {
        let menu = NSMenu()
        let versionItem = NSMenuItem(title: "Visor 0.9.1", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        let newSSH = NSMenuItem(title: "New SSH Connection…", action: #selector(addSSHProfile), keyEquivalent: "")
        newSSH.target = self
        menu.addItem(newSSH)
        if !profileStore.profiles.isEmpty {
            let saved = NSMenuItem(title: "Saved Connections", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "Saved Connections")
            for profile in profileStore.profiles {
                let item = NSMenuItem(title: profile.displayName, action: nil, keyEquivalent: "")
                item.submenu = profileMenu(for: profile)
                submenu.addItem(item)
            }
            saved.submenu = submenu
            menu.addItem(saved)
        }
        if case let .ssh(id)? = activeSession?.kind, let profile = profileStore.profile(id: id) {
            let reconnect = NSMenuItem(title: "Reconnect \(profile.displayName)", action: #selector(reconnectActiveSSH), keyEquivalent: "")
            reconnect.target = self
            menu.addItem(reconnect)
        }
        menu.addItem(.separator())
        let autoHideItem = NSMenuItem(
            title: "Auto-Hide When Clicking Outside",
            action: #selector(toggleAutoHide(_:)),
            keyEquivalent: ""
        )
        autoHideItem.target = self
        autoHideItem.state = settings.autoHide ? .on : .off
        menu.addItem(autoHideItem)

        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        displayItem.submenu = displaySelectionMenu()
        menu.addItem(displayItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Opacity", action: nil, keyEquivalent: "")
        let opacitySlider = NSSlider(value: Double(settings.opacity), minValue: 0.72, maxValue: 1, target: self, action: #selector(opacityChanged(_:)))
        opacitySlider.frame.size = NSSize(width: 210, height: 24)
        let opacityItem = NSMenuItem()
        opacityItem.view = opacitySlider
        menu.addItem(opacityItem)
        menu.addItem(.separator())
        let shortcutItem = NSMenuItem(
            title: "Keyboard Shortcut…  \(settings.keyboardShortcut.displayName)",
            action: #selector(changeKeyboardShortcut),
            keyEquivalent: ""
        )
        shortcutItem.target = self
        menu.addItem(shortcutItem)
        menu.addItem(withTitle: "Increase Font", action: #selector(increaseFont), keyEquivalent: "+")
        menu.addItem(withTitle: "Decrease Font", action: #selector(decreaseFont), keyEquivalent: "-")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Visor  \(settings.keyboardShortcut.displayName)", action: #selector(hideFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: "Quit Visor", action: #selector(quit), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        settings.opacity = CGFloat(sender.doubleValue)
        root.layer?.backgroundColor = NSColor.black.withAlphaComponent(settings.opacity).cgColor
    }

    private func displaySelectionMenu() -> NSMenu {
        let menu = NSMenu(title: "Display")
        let follow = NSMenuItem(title: "Follow Active Display", action: #selector(selectDisplay(_:)), keyEquivalent: "")
        follow.target = self
        follow.representedObject = NSNull()
        follow.state = settings.lockedScreenIdentifier == nil ? .on : .off
        menu.addItem(follow)
        menu.addItem(.separator())

        for (index, screen) in NSScreen.screens.enumerated() {
            guard let identifier = screen.visorPersistentIdentifier else { continue }
            let item = NSMenuItem(
                title: "Display \(index + 1) — \(screen.localizedName)",
                action: #selector(selectDisplay(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = identifier
            item.state = settings.lockedScreenIdentifier == identifier ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func toggleAutoHide(_ sender: NSMenuItem) {
        settings.autoHide.toggle()
        sender.state = settings.autoHide ? .on : .off
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        settings.lockedScreenIdentifier = sender.representedObject as? String
        guard isVisible, let frame = panelFrame(preferCurrentScreen: false) else { return }
        window?.setFrame(frame, display: true, animate: true)
        activeTerminalView?.fit()
    }

    @objc private func increaseFont() { changeFont(by: 1) }
    @objc private func decreaseFont() { changeFont(by: -1) }
    private func changeFont(by amount: CGFloat) {
        settings.fontSize = min(max(settings.fontSize + amount, 9), 30)
        terminalViews.values.forEach { $0.setFontSize(settings.fontSize) }
    }

    @objc func copyTerminalSelection() { activeTerminalView?.copySelection() }
    @objc func pasteIntoTerminal() { activeTerminalView?.paste() }
    @objc func selectAllTerminalText() { activeTerminalView?.selectAll() }
    @objc func clearTerminalScrollback() { activeTerminalView?.clearScrollback() }
    @objc private func changeKeyboardShortcut() {
        let recorder = ShortcutRecorderView(shortcut: settings.keyboardShortcut)
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcut"
        alert.informativeText = "Press a shortcut containing Control, Option, or Command."
        alert.accessoryView = recorder
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Use ⌥Space")

        let response = alert.runModal()
        guard response != .alertSecondButtonReturn else { return }
        let shortcut = response == .alertThirdButtonReturn ? KeyboardShortcut.defaultShortcut : recorder.shortcut
        guard let onShortcutChange else { return }
        switch onShortcutChange(shortcut) {
        case .success:
            break
        case let .failure(error):
            showError(error.localizedDescription)
        }
    }
    @objc private func hideFromMenu() { hide() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Visor"
        alert.informativeText = message
        alert.runModal()
    }

    func terminateSessions() { sessions.forEach { $0.terminate() } }

    func screenConfigurationChanged() {
        guard isVisible else { return }
        positionWindow()
        activeTerminalView?.fit()
    }
}
