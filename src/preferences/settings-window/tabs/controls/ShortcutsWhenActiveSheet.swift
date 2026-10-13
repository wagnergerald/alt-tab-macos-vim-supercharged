import Cocoa

class ShortcutsWhenActiveSheet: SheetWindow {
    private static let title = NSLocalizedString("Shortcuts When Active", comment: "")
    private static let labelSearchHint = NSLocalizedString("Show the search hint", comment: "")
    // Row titles come from `ControlsTab.staticShortcutLabels` (single source of truth, also used by
    // the conflict dialog to name these actions).
    private static let labelFocus = ControlsTab.staticShortcutLabels["focusWindowShortcut"]!
    private static let labelFocusAndSnap = ControlsTab.staticShortcutLabels["focusAndSnapWindowShortcut"]!
    private static let labelPrevious = ControlsTab.staticShortcutLabels["previousWindowShortcut"]!
    private static let labelCancel = ControlsTab.staticShortcutLabels["cancelShortcut"]!
    private static let labelSearch = ControlsTab.staticShortcutLabels["searchShortcut"]!
    private static let labelClose = ControlsTab.staticShortcutLabels["closeWindowShortcut"]!
    private static let labelMinDemin = ControlsTab.staticShortcutLabels["minDeminWindowShortcut"]!
    private static let labelFullscreen = ControlsTab.staticShortcutLabels["toggleFullscreenWindowShortcut"]!
    private static let labelQuit = ControlsTab.staticShortcutLabels["quitAppShortcut"]!
    private static let labelHideShow = ControlsTab.staticShortcutLabels["hideShowAppShortcut"]!
    private static let labelEnterHintMode = ControlsTab.staticShortcutLabels["enterHintModeFromNormalShortcut"]!
    private static let labelOpenSettings = ControlsTab.staticShortcutLabels["openSettingsFromSwitcherShortcut"]!
    private static let labelDismiss = ControlsTab.staticShortcutLabels["dismissSwitcherShortcut"]!
    private static let labelVimLeft = ControlsTab.staticShortcutLabels["vimCycleLeft"]!
    private static let labelVimRight = ControlsTab.staticShortcutLabels["vimCycleRight"]!
    private static let labelVimUp = ControlsTab.staticShortcutLabels["vimCycleUp"]!
    private static let labelVimDown = ControlsTab.staticShortcutLabels["vimCycleDown"]!

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    /// `ProBadgeView.proLabel` contributes the "Pro" tag rendered on the search row.
    static let searchableStrings: [String] = [
        title,
        labelFocus, labelFocusAndSnap, labelPrevious, labelCancel, labelEnterHintMode, labelOpenSettings,
        labelSearch, labelSearchHint,
        labelClose, labelMinDemin, labelFullscreen, labelQuit, labelHideShow,
        labelVimLeft, labelVimRight, labelVimUp, labelVimDown,
        labelDismiss,
        ProBadgeView.proLabel,
    ]

    override func makeContentView() -> NSView {
        let focusWindowShortcut = TableGroupView.Row(leftTitle: Self.labelFocus,
            subTitle: NSLocalizedString("shortcutsWhenActive.focusWindowSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelFocus, "focusWindowShortcut", Preferences.focusWindowShortcut, labelPosition: .right)[0]])
        let focusAndSnapWindowShortcut = TableGroupView.Row(leftTitle: Self.labelFocusAndSnap,
            subTitle: NSLocalizedString("snapLayout.focusAndSnapSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelFocusAndSnap, "focusAndSnapWindowShortcut", Preferences.focusAndSnapWindowShortcut, labelPosition: .right)[0]])
        let previousWindowShortcut = TableGroupView.Row(leftTitle: Self.labelPrevious,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelPrevious, "previousWindowShortcut", Preferences.previousWindowShortcut, labelPosition: .right)[0]])
        let cancelShortcut = TableGroupView.Row(leftTitle: Self.labelCancel,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelCancel, "cancelShortcut", Preferences.cancelShortcut, labelPosition: .right)[0]])
        let enterHintModeFromNormalShortcut = TableGroupView.Row(leftTitle: Self.labelEnterHintMode,
            subTitle: NSLocalizedString("shortcutsWhenActive.enterHintModeFromNormalSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelEnterHintMode, "enterHintModeFromNormalShortcut", Preferences.enterHintModeFromNormalShortcut, labelPosition: .right)[0]])
        let openSettingsFromSwitcherShortcut = TableGroupView.Row(leftTitle: Self.labelOpenSettings,
            subTitle: NSLocalizedString("shortcutsWhenActive.openSettingsFromSwitcherSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelOpenSettings, "openSettingsFromSwitcherShortcut", Preferences.openSettingsFromSwitcherShortcut, labelPosition: .right)[0]])
        let dismissSwitcherShortcut = TableGroupView.Row(leftTitle: Self.labelDismiss,
            subTitle: NSLocalizedString("shortcutsWhenActive.dismissSwitcherSubtitle", comment: ""),
            leftTitleBold: true,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelDismiss, "dismissSwitcherShortcut", Preferences.dismissSwitcherShortcut, labelPosition: .right)[0]])
        let table = TableGroupView(title: Self.title,
            subTitle: NSLocalizedString("shortcutsWhenActive.tableSubtitle", comment: ""),
            width: SheetWindow.width)
        _ = table.addRow(focusWindowShortcut)
        _ = table.addRow(focusAndSnapWindowShortcut)
        _ = table.addRow(previousWindowShortcut)
        _ = table.addRow(cancelShortcut)
        _ = table.addRow(enterHintModeFromNormalShortcut)
        _ = table.addRow(openSettingsFromSwitcherShortcut)
        let searchRow = table.addRow(leftText: Self.labelSearch,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelSearch, "searchShortcut", Preferences.searchShortcut, labelPosition: .right)[0]])
        addProBadgeToLeftLabel(searchRow)
        table.addRow(leftText: Self.labelSearchHint, rightViews: [LabelAndControl.makeSwitch("showSearchHint")])
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelVimLeft,
            subTitle: NSLocalizedString("vimNavigation.subtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelVimLeft, "vimCycleLeft", Preferences.shortcut("vimCycleLeft"), labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelVimRight,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelVimRight, "vimCycleRight", Preferences.shortcut("vimCycleRight"), labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelVimUp,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelVimUp, "vimCycleUp", Preferences.shortcut("vimCycleUp"), labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelVimDown,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelVimDown, "vimCycleDown", Preferences.shortcut("vimCycleDown"), labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelClose,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelClose, "closeWindowShortcut", Preferences.closeWindowShortcut, labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelMinDemin,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelMinDemin, "minDeminWindowShortcut", Preferences.minDeminWindowShortcut, labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelFullscreen,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelFullscreen, "toggleFullscreenWindowShortcut", Preferences.toggleFullscreenWindowShortcut, labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelQuit,
            subTitle: NSLocalizedString("shortcutsWhenActive.quitAppSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelQuit, "quitAppShortcut", Preferences.quitAppShortcut, labelPosition: .right)[0]]))
        _ = table.addRow(TableGroupView.Row(leftTitle: Self.labelHideShow,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelHideShow, "hideShowAppShortcut", Preferences.hideShowAppShortcut, labelPosition: .right)[0]]))
        let dismissTable = TableGroupView(title: NSLocalizedString("shortcutsWhenActive.dismissSwitcherSectionTitle", comment: ""),
            subTitle: NSLocalizedString("shortcutsWhenActive.dismissSwitcherSectionSubtitle", comment: ""),
            width: SheetWindow.width)
        _ = dismissTable.addRow(dismissSwitcherShortcut)
        return TableGroupSetView(originalViews: [table, dismissTable], padding: 0)
    }

    private func addProBadgeToLeftLabel(_ rowInfo: TableGroupView.RowInfo) {
        // Anchor the badge to the row's left label. Don't cast to a concrete view type: the label used
        // to be an `NSTextField` but `TableGroupView.makeText` now returns a `LightLabel` (an `NSView`),
        // and the old `as? NSTextField` silently failed that cast, dropping the badge. We only need
        // NSView anchors, so unwrap as-is and stay agnostic to future label type changes.
        guard let label = rowInfo.leftViews?.first else { return }
        let badge = ProBadgeView()
        label.superview?.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 4),
            badge.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: 1),
        ])
    }
}
