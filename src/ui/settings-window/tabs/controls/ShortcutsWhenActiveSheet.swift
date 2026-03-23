import Cocoa

class ShortcutsWhenActiveSheet: SheetWindow {
    private static func maxShortcutsContentHeight() -> CGFloat {
        guard let h = NSScreen.main?.visibleFrame.height, h > 0 else { return 480 }
        return min(540, max(280, h * 0.58))
    }

    private static func wrapInScrollView(_ inner: NSView) -> NSView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        if #available(macOS 11.0, *) {
            scrollView.automaticallyAdjustsContentInsets = false
        }
        let documentView = FlippedView(frame: .zero)
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        documentView.addSubview(inner)
        inner.translatesAutoresizingMaskIntoConstraints = false
        let maxH = maxShortcutsContentHeight()
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: documentView.topAnchor),
            inner.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: maxH),
        ])
        return scrollView
    }

    override func makeContentView() -> NSView {
        let focusWindowShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("Focus selected window", comment: ""),
            subTitle: NSLocalizedString("shortcutsWhenActive.focusWindowSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Focus selected window", comment: ""), "focusWindowShortcut", Preferences.focusWindowShortcut, labelPosition: .right)[0]])
        let previousWindowShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("Select previous window", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Select previous window", comment: ""), "previousWindowShortcut", Preferences.previousWindowShortcut, labelPosition: .right)[0]])
        let cancelShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("Cancel", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Cancel", comment: ""), "cancelShortcut", Preferences.cancelShortcut, labelPosition: .right)[0]])
        let enterHintModeFromNormalShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("shortcutsWhenActive.enterHintModeFromNormalTitle", comment: ""),
            subTitle: NSLocalizedString("shortcutsWhenActive.enterHintModeFromNormalSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("shortcutsWhenActive.enterHintModeFromNormalTitle", comment: ""), "enterHintModeFromNormalShortcut", Preferences.enterHintModeFromNormalShortcut, labelPosition: .right)[0]])
        let dismissSwitcherShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("Close the switcher immediately", comment: ""),
            subTitle: NSLocalizedString("shortcutsWhenActive.dismissSwitcherSubtitle", comment: ""),
            leftTitleBold: true,
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Close the switcher immediately", comment: ""), "dismissSwitcherShortcut", Preferences.dismissSwitcherShortcut, labelPosition: .right)[0]])
        let searchShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("Search", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Search", comment: ""), "searchShortcut", Preferences.searchShortcut, labelPosition: .right)[0]])
        let lockSearchShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("Lock search", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Lock search", comment: ""), "lockSearchShortcut", Preferences.lockSearchShortcut, labelPosition: .right)[0]])
        let openSettingsFromSwitcherShortcut = TableGroupView.Row(leftTitle: NSLocalizedString("Open settings while switcher is visible", comment: ""),
            subTitle: NSLocalizedString("shortcutsWhenActive.openSettingsFromSwitcherSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Open settings while switcher is visible", comment: ""), "openSettingsFromSwitcherShortcut", Preferences.openSettingsFromSwitcherShortcut, labelPosition: .right)[0]])
        let vimLeft = TableGroupView.Row(leftTitle: NSLocalizedString("Vim navigation — move left", comment: ""),
            subTitle: NSLocalizedString("vimNavigation.subtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Vim navigation — move left", comment: ""), "vimCycleLeft", Preferences.shortcut("vimCycleLeft"), labelPosition: .right)[0]])
        let vimRight = TableGroupView.Row(leftTitle: NSLocalizedString("Vim navigation — move right", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Vim navigation — move right", comment: ""), "vimCycleRight", Preferences.shortcut("vimCycleRight"), labelPosition: .right)[0]])
        let vimUp = TableGroupView.Row(leftTitle: NSLocalizedString("Vim navigation — move up", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Vim navigation — move up", comment: ""), "vimCycleUp", Preferences.shortcut("vimCycleUp"), labelPosition: .right)[0]])
        let vimDown = TableGroupView.Row(leftTitle: NSLocalizedString("Vim navigation — move down", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Vim navigation — move down", comment: ""), "vimCycleDown", Preferences.shortcut("vimCycleDown"), labelPosition: .right)[0]])
        let table = TableGroupView(title: NSLocalizedString("Shortcuts When Active", comment: ""),
            subTitle: NSLocalizedString("shortcutsWhenActive.tableSubtitle", comment: ""),
            width: SheetWindow.width)
        let dismissTable = TableGroupView(title: NSLocalizedString("shortcutsWhenActive.dismissSwitcherSectionTitle", comment: ""),
            subTitle: NSLocalizedString("shortcutsWhenActive.dismissSwitcherSectionSubtitle", comment: ""),
            width: SheetWindow.width)
        _ = table.addRow(focusWindowShortcut)
        _ = table.addRow(previousWindowShortcut)
        _ = table.addRow(cancelShortcut)
        _ = table.addRow(enterHintModeFromNormalShortcut)
        _ = table.addRow(searchShortcut)
        _ = table.addRow(lockSearchShortcut)
        _ = table.addRow(openSettingsFromSwitcherShortcut)
        _ = table.addRow(vimLeft)
        _ = table.addRow(vimRight)
        _ = table.addRow(vimUp)
        _ = table.addRow(vimDown)
        _ = dismissTable.addRow(dismissSwitcherShortcut)
        let inner = TableGroupSetView(originalViews: [table, dismissTable], bottomPadding: 0)
        return Self.wrapInScrollView(inner)
    }
}
