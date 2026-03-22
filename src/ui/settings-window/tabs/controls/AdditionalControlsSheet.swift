import Cocoa

class AdditionalControlsSheet: SheetWindow {
    private static func maxContentHeight() -> CGFloat {
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
        let maxH = maxContentHeight()
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
        let enableArrows = TableGroupView.Row(leftTitle: NSLocalizedString("Select windows using arrow keys", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("arrowKeysEnabled", extraAction: ControlsTab.arrowKeysEnabledCallback)])
        let enableVimKeys = TableGroupView.Row(leftTitle: NSLocalizedString("Select windows using vim keys", comment: ""),
            subTitle: NSLocalizedString("vimKeys.enableSubtitle", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("vimKeysEnabled", extraAction: ControlsTab.vimKeysEnabledCallback)])
        let enableWindowHints = TableGroupView.Row(
            leftTitle: NSLocalizedString("Show window hints on thumbnails", comment: ""),
            subTitle: NSLocalizedString("windowHints.explanationSettings", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("windowHintsEnabled")])
        let enableMouse = TableGroupView.Row(leftTitle: NSLocalizedString("Select windows on mouse hover", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("mouseHoverEnabled")])
        let enableCursorFollowFocus = TableGroupView.Row(leftTitle: NSLocalizedString("Cursor follows focus", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("cursorFollowFocus", CursorFollowFocus.allCases)])
        let enableTrackpadHapticFeedback = TableGroupView.Row(leftTitle: NSLocalizedString("Trackpad haptic feedback", comment: ""),
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
        let table1 = TableGroupView(title: NSLocalizedString("Additional controls", comment: ""),
            width: SheetWindow.width)
        _ = table1.addRow(enableArrows)
        _ = table1.addRow(enableVimKeys)
        _ = table1.addRow(enableWindowHints)
        _ = table1.addRow(enableMouse)
        let hintNavTable = TableGroupView(title: NSLocalizedString("additionalControls.hintModeNavigationTitle", comment: ""),
            subTitle: NSLocalizedString("additionalControls.hintModeNavigationSubtitle", comment: ""),
            width: SheetWindow.width)
        _ = hintNavTable.addRow(hintNavMinimize)
        _ = hintNavTable.addRow(hintNavClose)
        _ = hintNavTable.addRow(hintNavQuit)
        _ = hintNavTable.addRow(hintNavFullscreen)
        _ = hintNavTable.addRow(hintNavHide)
        let table2 = TableGroupView(title: NSLocalizedString("Miscellaneous", comment: ""),
            width: SheetWindow.width)
        _ = table2.addRow(enableCursorFollowFocus)
        _ = table2.addRow(enableTrackpadHapticFeedback)
        let view = TableGroupSetView(originalViews: [table1, hintNavTable, table2], padding: 0)
        return Self.wrapInScrollView(view)
    }
}
