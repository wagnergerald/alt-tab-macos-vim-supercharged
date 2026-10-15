import Cocoa

/// Small lock badge on tiles whose window exists but has no usable screenshot (e.g. KeePassXC
/// `NSWindowSharingNone`). Sized like `WindowlessAppIndicator` so the two overlays feel related.
class PreviewUnavailableIndicator: NSView {
    struct AppearanceParameter {
        let width: CGFloat
        let height: CGFloat
        let lineWidth: CGFloat
    }

    var lineWidth: CGFloat = 1.25

    convenience init(parameter: AppearanceParameter = PreviewUnavailableIndicator.getAppearanceParameter(),
                     tooltip: String? = nil) {
        self.init(frame: .zero)
        frame.size.width = parameter.width
        frame.size.height = parameter.height
        lineWidth = parameter.lineWidth
        toolTip = tooltip
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func reapplyAppearance() {
        let parameter = Self.getAppearanceParameter()
        frame.size = NSSize(width: parameter.width, height: parameter.height)
        lineWidth = parameter.lineWidth
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let color = Appearance.fontColor.withAlphaComponent(0.9)
        let w = bounds.width
        let h = bounds.height
        let bodyH = h * 0.46
        let bodyW = w * 0.70
        let body = CGRect(x: (w - bodyW) / 2, y: h * 0.06, width: bodyW, height: bodyH)
        let bodyPath = NSBezierPath(roundedRect: body, xRadius: bodyH * 0.22, yRadius: bodyH * 0.22)
        color.withAlphaComponent(0.20).setFill()
        bodyPath.fill()
        color.setStroke()
        bodyPath.lineWidth = lineWidth
        bodyPath.stroke()
        // Shackle: U-shape sitting on the body.
        let shackleW = bodyW * 0.52
        let leftX = body.midX - shackleW / 2
        let rightX = body.midX + shackleW / 2
        let baseY = body.maxY - lineWidth * 0.35
        let topY = min(h - lineWidth * 0.5, baseY + h * 0.36)
        let shackle = NSBezierPath()
        shackle.lineWidth = lineWidth
        shackle.lineCapStyle = .round
        shackle.lineJoinStyle = .round
        shackle.move(to: NSPoint(x: leftX, y: baseY))
        shackle.line(to: NSPoint(x: leftX, y: topY - shackleW * 0.15))
        shackle.appendArc(
            withCenter: NSPoint(x: body.midX, y: topY - shackleW * 0.15),
            radius: shackleW / 2,
            startAngle: 180,
            endAngle: 0,
            clockwise: false)
        shackle.line(to: NSPoint(x: rightX, y: baseY))
        color.setStroke()
        shackle.stroke()
        let holeR = max(1.0, min(bodyW, bodyH) * 0.11)
        let hole = NSBezierPath(ovalIn: CGRect(
            x: body.midX - holeR, y: body.midY - holeR * 0.15, width: holeR * 2, height: holeR * 2))
        color.setFill()
        hole.fill()
    }

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    static func getAppearanceParameter() -> AppearanceParameter {
        let style = Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex)
        if style == .thumbnails || style == .appIcons {
            if Appearance.resolvedSize == .large {
                return AppearanceParameter(width: 20, height: 22, lineWidth: 1.5)
            }
            return AppearanceParameter(width: 16, height: 18, lineWidth: 1.25)
        }
        if Appearance.resolvedSize == .large {
            return AppearanceParameter(width: 13, height: 15, lineWidth: 1.1)
        }
        return AppearanceParameter(width: 11, height: 13, lineWidth: 1)
    }
}
