import AppKit

enum PanelGeometry {
    static func visibleFrame(in screenFrame: NSRect, requestedHeight: CGFloat) -> NSRect {
        let height = min(max(requestedHeight, 220), screenFrame.height * 0.9)
        return NSRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - height,
            width: screenFrame.width,
            height: height
        )
    }

    static func hiddenFrame(for visibleFrame: NSRect) -> NSRect {
        NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }
}
