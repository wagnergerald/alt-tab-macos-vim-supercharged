import Cocoa

/// Mini screen outline with a filled sub-rect for a `SnapLayout`. Used in the live snap panel and Preferences.
final class SnapLayoutGlyphView: NSView {
    var layout: SnapLayout = .leftHalf {
        didSet { needsDisplay = true }
    }
    /// When set, preview that width step; otherwise the layout's default.
    var sizeStep: SnapSizeStep? {
        didSet { needsDisplay = true }
    }
    var outlineColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }
    var fillColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 40, height: 26) }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.insetBy(dx: 1.5, dy: 1.5)
        let screen = NSBezierPath(roundedRect: inset, xRadius: 2.5, yRadius: 2.5)
        outlineColor.setStroke()
        screen.lineWidth = 1.25
        screen.stroke()
        let frac = layout.placement(sizeStep: sizeStep ?? layout.defaultSizeStep)
        // Glyph is flipped (y down); placement.y is AppKit from bottom — invert for drawing.
        let fill = CGRect(
            x: inset.minX + inset.width * frac.x,
            y: inset.minY + inset.height * (1 - frac.y - frac.h),
            width: max(2, inset.width * frac.w),
            height: max(2, inset.height * frac.h)).insetBy(dx: 1.5, dy: 1.5)
        guard fill.width > 0.5, fill.height > 0.5 else { return }
        let region = NSBezierPath(roundedRect: fill, xRadius: 1.5, yRadius: 1.5)
        fillColor.withAlphaComponent(0.35).setFill()
        region.fill()
        fillColor.withAlphaComponent(0.95).setStroke()
        region.lineWidth = 1.25
        region.stroke()
    }
}
