import Cocoa

/// Overlay listing snap presets with key badge + glyph + label. Hosted by `TilesView` while `SnapSession` is active.
final class SnapLayoutPanelView: FlippedView {
    private let stack = NSStackView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var glyphs: [SnapLayout: SnapLayoutGlyphView] = [:]

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
        glyphs.removeAll(keepingCapacity: true)
        let title = NSTextField(labelWithString: NSLocalizedString("snapLayout.panelTitle", comment: ""))
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = fontColor
        title.alignment = .center
        stack.addArrangedSubview(title)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = fontColor.withAlphaComponent(0.85)
        statusLabel.alignment = .center
        refreshStatus(fontColor: fontColor)
        stack.addArrangedSubview(statusLabel)
        for layout in SnapLayout.allCases {
            stack.addArrangedSubview(makeRow(layout, fontColor: fontColor))
        }
        updateGlyphPreviews()
    }

    func refreshStatus(fontColor: NSColor? = nil) {
        if let fontColor { statusLabel.textColor = fontColor.withAlphaComponent(0.85) }
        if let pending = SnapSession.pendingSizeStep {
            statusLabel.stringValue = String(format: NSLocalizedString("snapLayout.panelPendingSize", comment: ""),
                                             pending.rawValue)
        } else {
            statusLabel.stringValue = NSLocalizedString("snapLayout.panelSizeHint", comment: "")
        }
        updateGlyphPreviews()
    }

    /// Pending digit redraws every row at that width; otherwise each row uses its default size.
    private func updateGlyphPreviews() {
        let pending = SnapSession.pendingSizeStep
        for layout in SnapLayout.allCases {
            guard let glyph = glyphs[layout] else { continue }
            glyph.sizeStep = pending
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
        keyBadge.widthAnchor.constraint(equalToConstant: 28).isActive = true
        let glyph = SnapLayoutGlyphView()
        glyph.layout = layout
        glyph.outlineColor = fontColor.withAlphaComponent(0.7)
        glyph.fillColor = NSColor.controlAccentColor
        glyph.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glyph.widthAnchor.constraint(equalToConstant: 40),
            glyph.heightAnchor.constraint(equalToConstant: 26),
        ])
        glyphs[layout] = glyph
        let label = NSTextField(labelWithString: layout.localizedTitle)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = fontColor
        let labelWidth = label.widthAnchor.constraint(equalToConstant: 140)
        labelWidth.priority = .defaultHigh
        labelWidth.isActive = true
        row.addArrangedSubview(keyBadge)
        row.addArrangedSubview(glyph)
        row.addArrangedSubview(label)
        return row
    }
}
