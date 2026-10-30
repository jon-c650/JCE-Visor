import XCTest
@testable import Visor

final class SSHCommandParserTests: XCTestCase {
    func testExtractsDeviceFromCommonSSHCommand() {
        XCTAssertEqual(SSHCommandParser.host(from: "ssh pi@raspberrypi.local"), "raspberrypi.local")
    }

    func testSkipsSSHOptionsAndTheirValues() {
        XCTAssertEqual(
            SSHCommandParser.host(from: "ssh -i '~/.ssh/home key' -p 2222 root@server"),
            "server"
        )
    }

    func testAllowsCommandAndSudoPrefixes() {
        XCTAssertEqual(SSHCommandParser.host(from: "command ssh -vv user@nas"), "nas")
        XCTAssertEqual(SSHCommandParser.host(from: "sudo ssh 10.0.0.8"), "10.0.0.8")
    }

    func testDoesNotTreatSSHArgumentsAsAConnection() {
        XCTAssertNil(SSHCommandParser.host(from: "echo ssh host"))
        XCTAssertNil(SSHCommandParser.host(from: "ssh -p 2222"))
    }
}
