import Cocoa

class WindowHintLabelView: FlippedView {
    private(set) var labelText = ""

    override var isOpaque: Bool { false }

    func setLabelText(_ text: String) {
        guard text != labelText else { return }
        labelText = text
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    private func attributedHint() -> NSAttributedString {
        let mapped = WindowHintLabels.circledGlyphString(for: labelText)
        let fontSize = (Appearance.fontHeight * 1.22).rounded()
        let font = NSFont(name: "SF Pro Text", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Appearance.fontColor, .paragraphStyle: TileFontIconView.paragraphStyle]
        return NSAttributedString(string: mapped, attributes: attrs)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !labelText.isEmpty else { return }
        let s = attributedHint()
        let size = s.size()
        let x = (bounds.width - size.width) / 2
        let y = (bounds.height - size.height) / 2
        s.draw(at: NSPoint(x: x, y: y))
    }

    override var intrinsicContentSize: NSSize {
        guard !labelText.isEmpty else { return .zero }
        let size = attributedHint().size()
        let padLeft: CGFloat
        let padRight: CGFloat
        if App.shared.userInterfaceLayoutDirection == .rightToLeft {
            padLeft = 2
            padRight = 4
        } else {
            padLeft = 4
            padRight = 2
        }
        let padV = CGFloat(4)
        return NSSize(width: ceil(size.width + padLeft + padRight), height: ceil(size.height + padV * 2))
    }
}
