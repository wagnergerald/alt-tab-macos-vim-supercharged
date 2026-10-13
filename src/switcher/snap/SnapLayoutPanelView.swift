import Cocoa

/// Overlay listing snap presets with key badge + glyph + label. Hosted by `TilesView` while `SnapSession` is active.
final class SnapLayoutPanelView: FlippedView {
    private let stack = NSStackView()
    private var rowViews: [NSView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload(fontColor: NSColor) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowViews.removeAll()
        let title = NSTextField(labelWithString: NSLocalizedString("snapLayout.panelTitle", comment: ""))
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = fontColor
        title.alignment = .center
        stack.addArrangedSubview(title)
        for layout in SnapLayout.allCases {
            stack.addArrangedSubview(makeRow(layout, fontColor: fontColor))
        }
    }

    private func makeRow(_ layout: SnapLayout, fontColor: NSColor) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        let key = Preferences.shortcutDisplayString(layout.preferenceKey)
        let keyBadge = NSTextField(labelWithString: key.isEmpty ? "·" : key)
        keyBadge.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        keyBadge.textColor = fontColor
        keyBadge.alignment = .center
        keyBadge.wantsLayer = true
        keyBadge.layer?.cornerRadius = 4
        keyBadge.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        keyBadge.setContentHuggingPriority(.required, for: .horizontal)
        let keyWidth = keyBadge.widthAnchor.constraint(equalToConstant: 28)
        keyWidth.isActive = true
        let glyph = SnapLayoutGlyphView()
        glyph.layout = layout
        glyph.outlineColor = fontColor.withAlphaComponent(0.7)
        glyph.fillColor = NSColor.controlAccentColor
        glyph.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glyph.widthAnchor.constraint(equalToConstant: 36),
            glyph.heightAnchor.constraint(equalToConstant: 24),
        ])
        let label = NSTextField(labelWithString: layout.localizedTitle)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = fontColor
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Fixed label width so every row’s key+glyph column lines up while the block stays centered.
        let labelWidth = label.widthAnchor.constraint(equalToConstant: 140)
        labelWidth.priority = .defaultHigh
        labelWidth.isActive = true
        row.addArrangedSubview(keyBadge)
        row.addArrangedSubview(glyph)
        row.addArrangedSubview(label)
        return row
    }
}
