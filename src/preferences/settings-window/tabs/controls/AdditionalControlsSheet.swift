import Cocoa

class AdditionalControlsSheet: SheetWindow {
    private static let title = NSLocalizedString("Additional controls", comment: "")
    private static let titleMiscellaneous = NSLocalizedString("Miscellaneous", comment: "")
    private static let labelArrows = NSLocalizedString("Select windows using arrow keys", comment: "")
    private static let labelVim = NSLocalizedString("Select windows using vim keys", comment: "")
    private static let labelWindowHints = NSLocalizedString("Show window hints on thumbnails", comment: "")
    private static let labelMouse = NSLocalizedString("Select windows on mouse hover", comment: "")
    private static let labelCursorFollow = NSLocalizedString("Cursor follows focus", comment: "")
    private static let labelTrackpad = NSLocalizedString("Trackpad haptic feedback", comment: "")
    private static let hintNavTitle = NSLocalizedString("additionalControls.hintModeNavigationTitle", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        title, titleMiscellaneous, hintNavTitle,
        labelArrows, labelVim, labelWindowHints, labelMouse,
        labelCursorFollow, labelTrackpad,
        NSLocalizedString("Minimize/Deminimize window", comment: ""),
        NSLocalizedString("Close window", comment: ""),
        NSLocalizedString("Quit app", comment: ""),
        NSLocalizedString("Fullscreen/Defullscreen window", comment: ""),
        NSLocalizedString("Hide/Show app", comment: ""),
    ] + CursorFollowFocus.allCases.map { $0.localizedString }

    override func makeContentView() -> NSView {
        let enableArrows = TableGroupView.Row(leftTitle: Self.labelArrows,
            rightViews: [LabelAndControl.makeSwitch("arrowKeysEnabled", extraAction: ControlsTab.arrowKeysEnabledCallback)])
        let enableVimKeys = TableGroupView.Row(leftTitle: Self.labelVim,
            subTitle: NSLocalizedString("vimKeys.enableSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("vimKeysEnabled", extraAction: ControlsTab.vimKeysEnabledCallback)])
        let enableWindowHints = TableGroupView.Row(
            leftTitle: Self.labelWindowHints,
            subTitle: NSLocalizedString("windowHints.explanationSettings", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("windowHintsEnabled")])
        let enableMouse = TableGroupView.Row(leftTitle: Self.labelMouse,
            rightViews: [LabelAndControl.makeSwitch("mouseHoverEnabled")])
        let enableCursorFollowFocus = TableGroupView.Row(leftTitle: Self.labelCursorFollow,
            rightViews: [LabelAndControl.makeDropdown("cursorFollowFocus", CursorFollowFocus.allCases)])
        let enableTrackpadHapticFeedback = TableGroupView.Row(leftTitle: Self.labelTrackpad,
            rightViews: [LabelAndControl.makeSwitch("trackpadHapticFeedbackEnabled")])
        let hintNavMinimize = TableGroupView.Row(leftTitle: NSLocalizedString("Minimize/Deminimize window", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Minimize/Deminimize window", comment: ""), "minDeminWindowShortcut", Preferences.minDeminWindowShortcut, labelPosition: .right)[0]])
        let hintNavClose = TableGroupView.Row(leftTitle: NSLocalizedString("Close window", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Close window", comment: ""), "closeWindowShortcut", Preferences.closeWindowShortcut, labelPosition: .right)[0]])
        let hintNavQuit = TableGroupView.Row(leftTitle: NSLocalizedString("Quit app", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Quit app", comment: ""), "quitAppShortcut", Preferences.quitAppShortcut, labelPosition: .right)[0]])
        let hintNavFullscreen = TableGroupView.Row(leftTitle: NSLocalizedString("Fullscreen/Defullscreen window", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Fullscreen/Defullscreen window", comment: ""), "toggleFullscreenWindowShortcut", Preferences.toggleFullscreenWindowShortcut, labelPosition: .right)[0]])
        let hintNavHide = TableGroupView.Row(leftTitle: NSLocalizedString("Hide/Show app", comment: ""),
            rightViews: [LabelAndControl.makeLabelWithRecorder(NSLocalizedString("Hide/Show app", comment: ""), "hideShowAppShortcut", Preferences.hideShowAppShortcut, labelPosition: .right)[0]])
        ControlsTab.arrowKeysCheckbox = enableArrows.rightViews[0] as? Switch
        ControlsTab.vimKeysCheckbox = enableVimKeys.rightViews[0] as? Switch
        ControlsTab.arrowKeysEnabledCallback(ControlsTab.arrowKeysCheckbox)
        ControlsTab.vimKeysEnabledCallback(ControlsTab.vimKeysCheckbox)
        let table1 = TableGroupView(title: Self.title, width: SheetWindow.width)
        _ = table1.addRow(enableArrows)
        _ = table1.addRow(enableVimKeys)
        _ = table1.addRow(enableWindowHints)
        _ = table1.addRow(enableMouse)
        let hintNavTable = TableGroupView(title: Self.hintNavTitle,
            subTitle: NSLocalizedString("additionalControls.hintModeNavigationSubtitle", comment: ""),
            width: SheetWindow.width)
        _ = hintNavTable.addRow(hintNavMinimize)
        _ = hintNavTable.addRow(hintNavClose)
        _ = hintNavTable.addRow(hintNavQuit)
        _ = hintNavTable.addRow(hintNavFullscreen)
        _ = hintNavTable.addRow(hintNavHide)
        let table2 = TableGroupView(title: Self.titleMiscellaneous, width: SheetWindow.width)
        _ = table2.addRow(enableCursorFollowFocus)
        _ = table2.addRow(enableTrackpadHapticFeedback)
        return TableGroupSetView(originalViews: [table1, hintNavTable, table2], padding: 0)
    }
}
