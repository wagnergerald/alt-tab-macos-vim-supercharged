import Cocoa

/// Small “no open window” badge on windowless app tiles. Drawn as an empty window glyph so it stays
/// readable on both icon and thumbnail layouts (the old 10×5 pill was easy to miss).
class WindowlessAppIndicator: NSView {
    struct AppearanceParameter {
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
        let lineWidth: CGFloat
    }

    var cornerRadius: CGFloat!
    var lineWidth: CGFloat = 1.25

    convenience init(parameter: AppearanceParameter = WindowlessAppIndicator.getAppearanceParameter(),
                     tooltip: String? = nil) {
        self.init(frame: .zero)
        frame.size.width = parameter.width
        frame.size.height = parameter.height
        cornerRadius = parameter.cornerRadius
        lineWidth = parameter.lineWidth
        toolTip = tooltip
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Re-apply appearance-baked size so a recycled instance survives an appearance change without
    /// being reallocated (which would free this tooltip owner; see TileView.reapplyAppearance).
    func reapplyAppearance() {
        let parameter = Self.getAppearanceParameter()
        frame.size = NSSize(width: parameter.width, height: parameter.height)
        cornerRadius = parameter.cornerRadius
        lineWidth = parameter.lineWidth
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let color = Appearance.fontColor.withAlphaComponent(0.85)
        let inset = lineWidth / 2
        let outer = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: outer, xRadius: cornerRadius, yRadius: cornerRadius)
        path.lineWidth = lineWidth
        // Soft fill so it reads on light and dark thumbnails.
        color.withAlphaComponent(0.18).setFill()
        path.fill()
        color.setStroke()
        path.stroke()
        // Title-bar rule — reads as an empty window, not a generic badge.
        let titleBarY = outer.maxY - max(3, outer.height * 0.28)
        let titleBar = NSBezierPath()
        titleBar.lineWidth = lineWidth
        titleBar.move(to: NSPoint(x: outer.minX, y: titleBarY))
        titleBar.line(to: NSPoint(x: outer.maxX, y: titleBarY))
        titleBar.stroke()
    }

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    static func getAppearanceParameter() -> AppearanceParameter {
        let style = Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex)
        if style == .thumbnails || style == .appIcons {
            if Appearance.resolvedSize == .large {
                return AppearanceParameter(width: 22, height: 16, cornerRadius: 3, lineWidth: 1.5)
            }
            return AppearanceParameter(width: 18, height: 13, cornerRadius: 2.5, lineWidth: 1.25)
        }
        if Appearance.resolvedSize == .large {
            return AppearanceParameter(width: 14, height: 10, cornerRadius: 2, lineWidth: 1.1)
        }
        return AppearanceParameter(width: 12, height: 9, cornerRadius: 2, lineWidth: 1)
    }
}
