import Carbon
import XCTest
@testable import Visor

final class KeyboardShortcutTests: XCTestCase {
    func testShortcutDisplayUsesMacModifierOrder() {
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey),
            keyLabel: "K"
        )
        XCTAssertEqual(shortcut.displayName, "⌃⌥⇧⌘K")
    }

    func testShortcutPersistsInSettings() throws {
        let suiteName = "VisorTests.Shortcut.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = VisorSettings(defaults: defaults)
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_Grave),
            modifiers: UInt32(controlKey),
            keyLabel: "`"
        )

        XCTAssertEqual(settings.keyboardShortcut, .defaultShortcut)
        settings.keyboardShortcut = shortcut
        XCTAssertEqual(VisorSettings(defaults: defaults).keyboardShortcut, shortcut)
    }
}
