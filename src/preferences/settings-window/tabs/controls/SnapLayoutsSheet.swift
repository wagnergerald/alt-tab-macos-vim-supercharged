import Cocoa

class SnapLayoutsSheet: SheetWindow {
    private static let title = NSLocalizedString("snapLayout.sheetTitle", comment: "")

    static let searchableStrings: [String] = {
        var strings = [title, ControlsTab.staticShortcutLabels["focusAndSnapWindowShortcut"]!]
        strings.append(contentsOf: SnapLayout.allCases.map(\.localizedTitle))
        return strings
    }()

    override func makeContentView() -> NSView {
        let focusTable = TableGroupView(title: Self.title,
            subTitle: NSLocalizedString("snapLayout.sheetSubtitle", comment: ""),
            width: SheetWindow.width)
        let focusLabel = ControlsTab.staticShortcutLabels["focusAndSnapWindowShortcut"]!
        _ = focusTable.addRow(TableGroupView.Row(
            leftTitle: focusLabel,
            subTitle: NSLocalizedString("snapLayout.focusAndSnapSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(focusLabel, "focusAndSnapWindowShortcut",
                Preferences.focusAndSnapWindowShortcut, labelPosition: .right)[0]]))
        let patterns = TableGroupView(title: NSLocalizedString("snapLayout.patternsSectionTitle", comment: ""),
            subTitle: NSLocalizedString("snapLayout.patternsSectionSubtitle", comment: ""),
            width: SheetWindow.width)
        for layout in SnapLayout.allCases {
            let glyph = SnapLayoutGlyphView()
            glyph.layout = layout
            glyph.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                glyph.widthAnchor.constraint(equalToConstant: 36),
                glyph.heightAnchor.constraint(equalToConstant: 24),
            ])
            let recorder = LabelAndControl.makeLabelWithRecorder(layout.localizedTitle, layout.preferenceKey,
                Preferences.shortcut(layout.preferenceKey), labelPosition: .right)[0]
            _ = patterns.addRow(TableGroupView.Row(
                leftTitle: layout.localizedTitle,
                rightViews: [glyph, recorder]))
        }
        return TableGroupSetView(originalViews: [focusTable, patterns], padding: 0)
    }
}
