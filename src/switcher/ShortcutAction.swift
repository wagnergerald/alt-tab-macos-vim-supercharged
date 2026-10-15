import Cocoa

struct ShortcutAction {
    let id: String
    let perform: () -> Void
}

enum ShortcutActions {
    private static func runFocusShortcutActionForCurrentHintMode() {
        switch TilesView.chooserHintMode {
        case .normal, .focusHints:
            App.focusTarget()
        case .minimizeHints:
            onSelectedWindow { $0.minDemin() }
            App.refreshUi(true)
        case .closeHints:
            onSelectedWindow(closesOneTab: true) { $0.close() }
        case .quitHints:
            onSelectedWindow { $0.application.quit() }
        case .fullscreenHints:
            onSelectedWindow { $0.toggleFullscreen() }
            App.refreshUi(true)
        case .hideHints:
            onSelectedWindow { $0.application.hideOrShow() }
            App.refreshUi(true)
        }
    }

    private static func enterHintModeOrRun(_ mode: ChooserHintMode, _ run: () -> Void) {
        guard Preferences.windowHintsEnabled else {
            run()
            return
        }
        if TilesView.chooserHintMode == mode { return }
        TilesView.switchToHintMode(mode)
    }

    static let all: [ShortcutAction] = {
        var actions: [ShortcutAction] = [
            ShortcutAction(id: "focusWindowShortcut", perform: {
                if SnapSession.isActive {
                    App.focusSnapTargetWithoutResizing()
                    return
                }
                if !Preferences.windowHintsEnabled {
                    App.focusTarget()
                    return
                }
                runFocusShortcutActionForCurrentHintMode()
            }),
            ShortcutAction(id: "focusAndSnapWindowShortcut", perform: { App.enterSnapLayoutMode() }),
            ShortcutAction(id: "enterHintModeFromNormalShortcut", perform: {
                guard !SnapSession.isActive else { return }
                guard Preferences.windowHintsEnabled else { return }
                switch TilesView.chooserHintMode {
                case .normal, .minimizeHints, .closeHints, .quitHints, .hideHints:
                    TilesView.switchToHintMode(.focusHints)
                default:
                    break
                }
            }),
            ShortcutAction(id: "openSettingsFromSwitcherShortcut", perform: { App.showSettingsWindow() }),
            ShortcutAction(id: "previousWindowShortcut", perform: {
                guard !SnapSession.isActive else { return }
                App.previousWindowShortcutWithRepeatingKey()
            }),
            ShortcutAction(id: "→", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.right) }),
            ShortcutAction(id: "←", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.left) }),
            ShortcutAction(id: "↑", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.up) }),
            ShortcutAction(id: "↓", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.down) }),
            ShortcutAction(id: "vimCycleRight", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.right) }),
            ShortcutAction(id: "vimCycleLeft", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.left) }),
            ShortcutAction(id: "vimCycleUp", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.up) }),
            ShortcutAction(id: "vimCycleDown", perform: { guard !SnapSession.isActive else { return }; App.cycleSelection(.down) }),
            ShortcutAction(id: "cancelShortcut", perform: {
                guard let session = SwitcherSession.current else { return }
                if SnapSession.isActive {
                    App.handleSnapCancel()
                    return
                }
                let entry: SearchEntryStyle = Preferences.effectiveShortcutStyle(session.shortcutIndex) == .searchOnRelease ? .startedInSearch : .toggledMidSession
                switch SearchModeResolver.escape(mode: TilesView.searchMode, entry: entry) {
                    case .exitSearch: TilesView.disableSearchMode()
                    case .closeSwitcher: App.hideUi()
                }
            }),
            ShortcutAction(id: "closeWindowShortcut", perform: {
                guard !SnapSession.isActive else { return }
                enterHintModeOrRun(.closeHints) { onSelectedWindow(closesOneTab: true) { $0.close() } }
            }),
            ShortcutAction(id: "minDeminWindowShortcut", perform: {
                guard !SnapSession.isActive else { return }
                enterHintModeOrRun(.minimizeHints) { onSelectedWindow { $0.minDemin() } }
            }),
            ShortcutAction(id: "toggleFullscreenWindowShortcut", perform: {
                guard !SnapSession.isActive else { return }
                enterHintModeOrRun(.fullscreenHints) { onSelectedWindow { $0.toggleFullscreen() } }
            }),
            ShortcutAction(id: "quitAppShortcut", perform: {
                guard !SnapSession.isActive else { return }
                enterHintModeOrRun(.quitHints) { onSelectedWindow { $0.application.quit() } }
            }),
            ShortcutAction(id: "hideShowAppShortcut", perform: {
                guard !SnapSession.isActive else { return }
                enterHintModeOrRun(.hideHints) { onSelectedWindow { $0.application.hideOrShow() } }
            }),
            ShortcutAction(id: "searchShortcut", perform: {
                guard SwitcherSession.isActive, !SnapSession.isActive else { return }
                TilesView.toggleSearchModeFromShortcut()
            }),
            ShortcutAction(id: "dismissSwitcherShortcut", perform: {
                guard !Preferences.windowHintsEnabled || TilesView.windowHintMode || SnapSession.isActive else { return }
                App.hideUi()
            }),
        ]
        for layout in SnapLayout.allCases {
            let captured = layout
            actions.append(ShortcutAction(id: captured.preferenceKey, perform: {
                App.applySnapLayout(captured)
            }))
        }
        return actions
    }()

    /// Acting on a tile is a commitment to THAT window, so from here the selection follows it by id rather
    /// than being re-derived as the default pick. Every one of these actions reorders the list under the
    /// open switcher — fullscreen moves the window to its own Space, minimize/hide/quit move the MRU — and
    /// the default pick means "the second visible window", so it stayed on the SLOT while the window the
    /// user aimed at slid out of it. Live: F fullscreened the selected window, the list reordered, and a
    /// second F to undo fullscreened a different app's window instead (measured live).
    private static func onSelectedWindow(closesOneTab: Bool = false, _ act: (Window) -> Void) {
        guard let window = Windows.selectedWindow() else { return }
        Windows.commitToActionTarget(window, closesOneTab: closesOneTab)
        act(window)
    }

    private static let byId: [String: ShortcutAction] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func find(_ id: String) -> ShortcutAction? {
        byId[id]
    }

    static func execute(_ id: String) {
        // Gate *pressing* a Pro-only shortcut slot (index >= 1). Without this, configured Cmd+Tab
        // variants past the first keep working after Day15 lock. Mirrors the `.search` gate in
        // `TilesView` and the slot-add gate in `addShortcutSlot()`.
        if id.hasPrefix("holdShortcut") || id.hasPrefix("nextWindowShortcut") {
            let index = Preferences.nameToIndex(id)
            if index >= 1 {
                if !ProFeature.extraShortcut(index: index).attemptUse() { return }
            }
        }
        if let action = find(id) {
            action.perform()
            return
        }
        if id.hasPrefix("holdShortcut") {
            App.focusTarget()
            return
        }
        if id.hasPrefix("nextWindowShortcut") {
            App.showUiOrCycleSelection(Preferences.nameToIndex(id), false)
        }
    }
}
