import XCTest
@testable import Visor

final class SSHProfileTests: XCTestCase {
    func testCommandUsesSeparateArguments() {
        let profile = SSHProfile(
            name: "Production",
            host: "server.example.com",
            user: "deploy",
            port: 2222,
            identityFile: "/tmp/test key"
        )

        XCTAssertEqual(profile.command, [
            "/usr/bin/ssh", "-p", "2222", "-i", "/tmp/test key",
            "--", "deploy@server.example.com"
        ])
    }

    func testStoreSavesUpdatesAndDeletesProfiles() throws {
        let suiteName = "VisorTests.SSHProfiles.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SSHProfileStore(defaults: defaults)
        var profile = SSHProfile(name: "Home", host: "home.example.com")
        store.save(profile)
        XCTAssertEqual(SSHProfileStore(defaults: defaults).profiles, [profile])

        profile.name = "Home Server"
        store.save(profile)
        XCTAssertEqual(store.profiles, [profile])

        store.delete(id: profile.id)
        XCTAssertTrue(store.profiles.isEmpty)
    }
}
