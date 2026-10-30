import XCTest
@testable import Visor

final class SettingsTests: XCTestCase {
    func testAutoHideDefaultsOnAndPersistsChanges() throws {
        let suiteName = "VisorTests.AutoHide.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = VisorSettings(defaults: defaults)
        XCTAssertTrue(settings.autoHide)

        settings.autoHide = false
        XCTAssertFalse(VisorSettings(defaults: defaults).autoHide)

        settings.autoHide = true
        XCTAssertTrue(VisorSettings(defaults: defaults).autoHide)
    }

    func testLockedScreenIdentifierPersistsAndCanReturnToFollowMode() throws {
        let suiteName = "VisorTests.Screen.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = VisorSettings(defaults: defaults)
        XCTAssertNil(settings.lockedScreenIdentifier)

        settings.lockedScreenIdentifier = "display-123-456-789"
        XCTAssertEqual(VisorSettings(defaults: defaults).lockedScreenIdentifier, "display-123-456-789")

        settings.lockedScreenIdentifier = nil
        XCTAssertNil(VisorSettings(defaults: defaults).lockedScreenIdentifier)
    }
}
