import XCTest
@testable import Visor

final class TerminalSessionTests: XCTestCase {
    func testLargePasteIsWrittenCompletely() throws {
        let ending = "VISOR_LARGE_PASTE_END"
        let received = expectation(description: "complete pasted payload")
        let session = try TerminalSession(title: "paste", command: ["/bin/cat"])
        let payload = String(repeating: "terminal paste data\n", count: 6_000) + ending + "\n"
        var output = Data()
        var didReceiveEnding = false

        session.onOutput = { data in
            output.append(data)
            if output.range(of: Data(ending.utf8)) != nil, !didReceiveEnding {
                didReceiveEnding = true
                received.fulfill()
            }
        }

        session.send(Data(payload.utf8))
        wait(for: [received], timeout: 5)
        XCTAssertTrue(output.range(of: Data(ending.utf8)) != nil)
        session.terminate()
    }

    func testTypingSSHCommandRenamesShellSession() throws {
        let session = try TerminalSession(title: "shell 1", command: ["/bin/cat"])
        var titleChangeCount = 0
        session.onTitleChange = { titleChangeCount += 1 }

        session.send(Data("ssh admin@workstation.local\r".utf8))

        XCTAssertEqual(session.title, "workstation.local")
        XCTAssertEqual(titleChangeCount, 1)
        session.terminate()
    }

    func testExitRestoresShellTitleAfterSSH() throws {
        let session = try TerminalSession(title: "shell 1", command: ["/bin/cat"])

        session.send(Data("ssh admin@workstation.local\r".utf8))
        XCTAssertEqual(session.title, "workstation.local")

        session.send(Data("exit\r".utf8))
        XCTAssertEqual(session.title, "shell 1")
        session.terminate()
    }

    func testControlDRestoresShellTitleAfterSSH() throws {
        let session = try TerminalSession(title: "shell 1", command: ["/bin/cat"])

        session.send(Data("ssh admin@workstation.local\r".utf8))
        XCTAssertEqual(session.title, "workstation.local")

        session.send(Data([0x04]))
        XCTAssertEqual(session.title, "shell 1")
        session.terminate()
    }

    func testInteractiveShellReceivesTypedCommand() throws {
        let marker = "VISOR_PTY_INPUT_OK"
        let received = expectation(description: "shell output")
        let session = try TerminalSession(title: "test", command: ["/bin/zsh", "-f"])
        var parser = ANSIParser()
        var rendered = ""
        var didReceiveMarker = false

        session.onOutput = { data in
            rendered += parser.parse(data, fontSize: 14).string
            if rendered.contains(marker), !didReceiveMarker {
                didReceiveMarker = true
                received.fulfill()
            }
        }

        session.send(Data("printf '\(marker)\\n'\n".utf8))
        wait(for: [received], timeout: 3)
        XCTAssertTrue(String(decoding: session.transcript, as: UTF8.self).contains(marker))
        session.terminate()
    }

    func testShellHasAControllingTerminalForSSH() throws {
        let received = expectation(description: "tty path")
        let session = try TerminalSession(title: "test", command: ["/bin/zsh", "-f"])
        var output = ""
        var didReceiveTTY = false

        session.onOutput = { data in
            output += String(decoding: data, as: UTF8.self)
            if output.contains("/dev/ttys"), !didReceiveTTY {
                didReceiveTTY = true
                received.fulfill()
            }
        }

        session.send(Data("tty\n".utf8))
        wait(for: [received], timeout: 3)
        XCTAssertFalse(output.contains("not a tty"))
        session.terminate()
    }
}
