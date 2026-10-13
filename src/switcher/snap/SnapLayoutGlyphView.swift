import Cocoa

/// Mini screen outline with a filled sub-rect for a `SnapLayout`. Used in the live snap panel and Preferences.
final class SnapLayoutGlyphView: NSView {
    var layout: SnapLayout = .leftHalf {
        didSet { needsDisplay = true }
    }
    var outlineColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }
    var fillColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 36, height: 24) }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: inset, xRadius: 2, yRadius: 2)
        outlineColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        let frac = layout.horizontalFractions
        let fill = CGRect(
            x: inset.minX + inset.width * frac.x,
            y: inset.minY,
            width: max(1, inset.width * frac.w),
            height: inset.height).insetBy(dx: 1, dy: 1)
        fillColor.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: fill, xRadius: 1, yRadius: 1).fill()
    }
}
