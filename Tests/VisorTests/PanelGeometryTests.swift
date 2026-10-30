import AppKit
import XCTest
@testable import Visor

final class PanelGeometryTests: XCTestCase {
    func testVisibleFrameAnchorsPanelToTopOfScreen() {
        let screen = NSRect(x: 40, y: 80, width: 1440, height: 900)

        let frame = PanelGeometry.visibleFrame(in: screen, requestedHeight: 500)

        XCTAssertEqual(frame, NSRect(x: 40, y: 480, width: 1440, height: 500))
    }

    func testVisibleFrameClampsHeight() {
        let screen = NSRect(x: 0, y: 0, width: 1200, height: 600)

        XCTAssertEqual(PanelGeometry.visibleFrame(in: screen, requestedHeight: 100).height, 220)
        XCTAssertEqual(PanelGeometry.visibleFrame(in: screen, requestedHeight: 900).height, 540)
    }

    func testHiddenFrameMovesPanelJustAboveVisibleScreen() {
        let visible = NSRect(x: 40, y: 480, width: 1440, height: 500)

        let hidden = PanelGeometry.hiddenFrame(for: visible)

        XCTAssertEqual(hidden, NSRect(x: 40, y: 980, width: 1440, height: 500))
    }
}
