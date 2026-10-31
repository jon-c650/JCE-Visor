import XCTest
@testable import Visor

final class SSHKeySupportTests: XCTestCase {
    func testStorablePathUsesTildeInsideHomeDirectory() {
        XCTAssertEqual(
            SSHKeySupport.storablePath("/Users/test/.ssh/id_ed25519", homeDirectory: "/Users/test"),
            "~/.ssh/id_ed25519"
        )
        XCTAssertEqual(
            SSHKeySupport.storablePath("/Volumes/Keys/id_ed25519", homeDirectory: "/Users/test"),
            "/Volumes/Keys/id_ed25519"
        )
    }

    func testGenerationCommandUsesStrongEd25519Defaults() {
        XCTAssertEqual(
            SSHKeySupport.generationCommand(path: "/tmp/id_ed25519"),
            ["/usr/bin/ssh-keygen", "-t", "ed25519", "-a", "64", "-f", "/tmp/id_ed25519"]
        )
    }

    func testInstallCommandKeepsConnectionValuesAsSeparateArguments() {
        let profile = SSHProfile(
            name: "Production",
            host: "server.example.com",
            user: "deploy",
            port: 2222,
            identityFile: "/tmp/test key"
        )
        let command = SSHKeySupport.installCommand(
            profile: profile,
            publicKey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest visor"
        )

        XCTAssertEqual(command.prefix(5), [
            "/bin/sh", "-c", #"key=$1; shift; printf '%s\n' "$key" | exec "$@""#,
            "visor-key-install", "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest visor"
        ])
        XCTAssertEqual(Array(command[5...10]), [
            "/usr/bin/ssh", "-p", "2222", "-i", "/tmp/test key", "--"
        ])
        XCTAssertEqual(command[11], "deploy@server.example.com")
        XCTAssertTrue(command[12].contains("authorized_keys"))
    }

    func testTestCommandRequiresKeyAuthenticationWithoutDisablingPassphrasePrompts() {
        let profile = SSHProfile(name: "Lab", host: "lab.local", user: "jon", identityFile: "~/.ssh/id_ed25519")
        let command = SSHKeySupport.testCommand(profile: profile)

        XCTAssertTrue(command.contains("PreferredAuthentications=publickey"))
        XCTAssertTrue(command.contains("PasswordAuthentication=no"))
        XCTAssertTrue(command.contains("KbdInteractiveAuthentication=no"))
        XCTAssertFalse(command.contains("BatchMode=yes"))
        XCTAssertTrue(command.contains("ConnectTimeout=8"))
        XCTAssertEqual(command.suffix(2), ["jon@lab.local", "printf 'SSH key login succeeded.\\n'"])
    }

    func testKeychainCommandUsesAppleKeychainWithoutEmbeddingAPassphrase() throws {
        let profile = SSHProfile(name: "Lab", host: "lab.local", identityFile: "~/.ssh/id_ed25519")
        XCTAssertEqual(
            try SSHKeySupport.keychainCommand(profile: profile),
            ["/usr/bin/ssh-add", "--apple-use-keychain", ("~/.ssh/id_ed25519" as NSString).expandingTildeInPath]
        )
    }

    func testReadPublicKeyValidatesPrivateAndPublicFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let privateURL = directory.appendingPathComponent("id_test")
        let publicURL = directory.appendingPathComponent("id_test.pub")
        try Data().write(to: privateURL)
        try "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest visor@example\n".write(to: publicURL, atomically: true, encoding: .utf8)

        let profile = SSHProfile(name: "Test", host: "test.local", identityFile: privateURL.path)
        XCTAssertEqual(
            try SSHKeySupport.readPublicKey(for: profile),
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest visor@example"
        )
    }
}
