import Cocoa
import Carbon.HIToolbox.Events
import Carbon
import ShortcutRecorder
import UniformTypeIdentifiers

enum SearchKeyResult {
    case handled
    case passToField
    case passToShortcuts
}

enum ChooserHintMode: Equatable {
    case normal
    case focusHints
    case minimizeHints
    case closeHints
    case quitHints
    case fullscreenHints
    case hideHints
}

class TilesView {
    static var scrollView: ScrollView!
    static var contentView: EffectView!
    static var currentEffectViewKind: EffectViewKind?
    private static var cachedEffectViews: [EffectViewKind: EffectView] = [:]
    static var searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 320, height: 30))
    static var noWindowLabel = NSTextField(labelWithString: NSLocalizedString("No Window", comment: ""))
    private static let hintBannerGapNormal: CGFloat = 4
    private static let hintBannerGapHint: CGFloat = 4
    private static let searchTabHintGap: CGFloat = 8
    private static let chooserBannerLineSeparator = " · "
    private static let chooserBannerMinHeight: CGFloat = 14
    private static var chooserBannerCachedHeight: CGFloat = 14
    private static var chooserBannerLabel = NSTextField(wrappingLabelWithString: "")
    private static var searchTabHintLabel = NSTextField(labelWithString: "")
    static var chooserHintMode: ChooserHintMode = .normal
    static var windowHintMode: Bool { chooserHintMode != .normal }
    static var windowHintKeyBuffer = ""
    static var searchFieldYieldsToHints = false
    private static var windowHintLabelAtIndex = [String]()
    private(set) static var searchMode: SearchMode = .off
    static var rows = [[TileView]]()
    private static var lastRowSignature = [Int]()
    static var recycledViews = [TileView]()
    static var thumbnailsWidth = CGFloat(0.0)
    static var thumbnailsHeight = CGFloat(0.0)
    static var layoutCache = LayoutCache()
    static var thumbnailUnderLayer = TileUnderLayer()
    static var thumbnailOverView = TileOverView()
    private static var snapLayoutPanel = SnapLayoutPanelView(frame: .zero)
    private static var initialized = false

    static func initialize() {
        guard !initialized else { return }
        configureSearchField()
        configureNoWindowLabel()
        configureHintChrome()
        snapLayoutPanel.isHidden = true
        updateBackgroundView()
        initialized = true
        growPoolToCoverWindows()
        Self.updateCachedSizes()
    }

    static func showSnapLayoutPanel() {
        guard contentView != nil else { return }
        let host = contentView.hostView
        if snapLayoutPanel.superview !== host {
            host.addSubview(snapLayoutPanel)
        }
        snapLayoutPanel.reload(fontColor: Appearance.fontColor)
        snapLayoutPanel.isHidden = false
        layoutSnapLayoutPanel()
        scrollView?.isHidden = true
        noWindowLabel.isHidden = true
        updateChooserBannerForSnapMode()
    }

    static func refreshSnapLayoutPanelStatus() {
        guard SnapSession.isActive, !snapLayoutPanel.isHidden else { return }
        snapLayoutPanel.refreshStatus(fontColor: Appearance.fontColor)
        updateChooserBannerForSnapMode()
    }

    static func hideSnapLayoutPanel() {
        snapLayoutPanel.isHidden = true
        snapLayoutPanel.removeFromSuperview()
        scrollView?.isHidden = false
        syncWindowHintsChromeBanners()
    }

    /// Leave snap UI without focusing the locked window. Keeps the chooser hint mode that was active
    /// before the uppercase/Enter snap entry (e.g. focus hints), matching pre-snap AltTab behavior.
    static func exitSnapLayoutModeToWindowSelection() {
        hideSnapLayoutPanel()
        focusSelectedTileIfPossible()
        applyWindowHintLabels()
        syncWindowHintsChromeBanners()
    }

    private static func layoutSnapLayoutPanel() {
        guard !snapLayoutPanel.isHidden, let scrollView else { return }
        snapLayoutPanel.frame = scrollView.frame
    }

    private static func updateChooserBannerForSnapMode() {
        guard Preferences.windowHintsEnabled else { return }
        chooserBannerLabel.isHidden = false
        let title = NSLocalizedString("snapLayout.bannerTitle", comment: "")
        var detail = NSLocalizedString("snapLayout.bannerDetail", comment: "")
        if let pending = SnapSession.pendingSizeStep {
            detail = String(format: NSLocalizedString("snapLayout.panelPendingSize", comment: ""), pending.rawValue)
        }
        let result = NSMutableAttributedString(
            string: title + " ",
            attributes: [.font: chooserBannerTitleFont(), .foregroundColor: Appearance.fontColor])
        result.append(NSAttributedString(
            string: detail,
            attributes: [.font: chooserBannerDetailFont(), .foregroundColor: Appearance.fontColor.withAlphaComponent(0.85)]))
        chooserBannerLabel.attributedStringValue = result
    }

    static func growPoolToCoverWindows() {
        let count = TilePool.tilesToAdd(poolSize: recycledViews.count, windowCount: Windows.list.count, uiIsBuilt: initialized)
        (0..<count).forEach { _ in recycledViews.append(TileView()) }
    }

    static var isSearchModeOn: Bool { searchMode != .off }
    static var isSearchEditing: Bool { searchMode == .editing }

    static func startSearchSession(_ startInSearchMode: Bool) {
        searchField.stringValue = ""
        Windows.updateSearchQuery("")
        searchFieldYieldsToHints = false
        searchMode = SearchModeResolver.startMode(startInSearch: startInSearchMode)
        updateSearchFieldEditability()
    }

    static func endSearchSession() {
        MainThreadStall.step()
        Windows.updateSearchQuery("")
        TilesPanel.shared.resetFrozenPosition()
        searchFieldYieldsToHints = false
        searchMode = .off
        takeTheCaretFromTheField()
    }

    /// The counterpart to `giveTheFieldTheCaret`, and a turn late for the mirror reason: clearing the field
    /// and dropping its editability resigns it as first responder, and AppKit answers that by DEACTIVATING
    /// the system text-input context, a synchronous XPC to the input-method services (`CursorUIViewService`,
    /// `CharacterPalette`). Measured 4-7ms on macOS 26.6.2, but it is unbounded: on one user's machine it
    /// returned only by timing out after 3.0s, and the whole dismissal sat behind it (#5981). Callers run it
    /// last, behind whatever the user is actually waiting for: the panel hiding, or the re-layout that puts
    /// the unfiltered list back.
    /// `focusingSelectedTile` moves the tile focus into the same deferred turn: handing first responder to the
    /// tile resigns the field just the same.
    private static func takeTheCaretFromTheField(focusingSelectedTile: Bool = false) {
        DispatchQueue.main.async {
            guard searchMode == .off else { return } // search restarted meanwhile and owns the field now
            if focusingSelectedTile && SwitcherSession.current != nil { focusSelectedTileIfPossible() }
            searchField.stringValue = ""
            updateSearchFieldEditability()
        }
    }

    static func resetWindowHintState() {
        chooserHintMode = Preferences.windowHintsEnabled ? .focusHints : .normal
        windowHintKeyBuffer = ""
    }

    static func onWindowHintsPreferenceChanged() {
        if !Preferences.windowHintsEnabled {
            chooserHintMode = .normal
            windowHintKeyBuffer = ""
        } else {
            chooserHintMode = .focusHints
        }
        applyWindowHintLabels()
        syncWindowHintsChromeBanners()
        focusSelectedTileIfPossible()
        Windows.voiceOverWindow()
        syncSearchFieldTabHintToolTip()
    }

    static func onWindowHintsShortcutDisplayChanged() {
        guard SwitcherSession.isActive else { return }
        applyWindowHintLabels()
        syncWindowHintsChromeBanners()
    }

    static func exitWindowHintMode() {
        guard Preferences.windowHintsEnabled, chooserHintMode != .normal else { return }
        chooserHintMode = .normal
        windowHintKeyBuffer = ""
        applyWindowHintLabels()
        syncWindowHintsChromeBanners()
        focusSelectedTileIfPossible()
        Windows.voiceOverWindow()
    }

    static func handleWindowHintKeyDown(_ event: NSEvent, _ isARepeat: Bool) -> Bool {
        guard Preferences.windowHintsEnabled, windowHintMode else { return false }
        if isARepeat { return false }
        if event.type != .keyDown { return false }
        if event.keyCode == UInt16(kVK_Escape) {
            exitWindowHintMode()
            return true
        }
        let blocked = event.modifierFlags.intersection([.option, .command, .control])
        if !blocked.isEmpty { return false }
        guard let parsed = keyCharacterForWindowHint(event) else { return false }
        guard WindowHintLabels.isHintCharacter(parsed.ch) else { return false }
        return processWindowHintCharacter(parsed.ch, enterSnapOnActivate: parsed.wantsSnap)
    }

    /// Hint labels are lowercase. Uppercase typing (Shift or Caps Lock producing an uppercase letter)
    /// still targets the same label, but completing the hint opens the snap layout panel instead of focusing.
    private static func keyCharacterForWindowHint(_ event: NSEvent) -> (ch: String, wantsSnap: Bool)? {
        let ignoring = event.charactersIgnoringModifiers ?? event.characters ?? ""
        guard let first = ignoring.first else { return nil }
        let ch = String(first).lowercased()
        let produced = event.characters ?? ""
        let wantsSnap = produced.first.map { $0.isLetter && $0.isUppercase } ?? false
        return (ch, wantsSnap)
    }

    private static func processWindowHintCharacter(_ ch: String, enterSnapOnActivate: Bool) -> Bool {
        let newBuffer = windowHintKeyBuffer + ch
        let matches = (0..<Windows.list.count).filter { i in
            let label = i < windowHintLabelAtIndex.count ? windowHintLabelAtIndex[i] : ""
            return !label.isEmpty && label.hasPrefix(newBuffer)
        }
        if matches.isEmpty {
            windowHintKeyBuffer = ch
            let retry = (0..<Windows.list.count).filter { i in
                let label = i < windowHintLabelAtIndex.count ? windowHintLabelAtIndex[i] : ""
                return !label.isEmpty && label.hasPrefix(windowHintKeyBuffer)
            }
            if retry.count == 1, retry[0] < windowHintLabelAtIndex.count, windowHintLabelAtIndex[retry[0]] == windowHintKeyBuffer {
                activateWindowFromHint(retry[0], enterSnap: enterSnapOnActivate)
                return true
            }
            if retry.isEmpty {
                windowHintKeyBuffer = ""
                return false
            }
            return true
        }
        windowHintKeyBuffer = newBuffer
        if matches.count == 1, matches[0] < windowHintLabelAtIndex.count, windowHintLabelAtIndex[matches[0]] == windowHintKeyBuffer {
            activateWindowFromHint(matches[0], enterSnap: enterSnapOnActivate)
            return true
        }
        return true
    }

    private static func activateWindowFromHint(_ index: Int, enterSnap: Bool = false) {
        windowHintKeyBuffer = ""
        Windows.updateSelectedAndHoveredWindowIndex(index)
        switch chooserHintMode {
        case .normal, .focusHints:
            if enterSnap {
                App.enterSnapLayoutMode()
            } else {
                App.focusSelectedWindow(Windows.selectedWindow())
            }
        case .minimizeHints:
            App.minDeminSelectedWindow()
            App.refreshUi(true)
        case .closeHints:
            App.closeSelectedWindow()
        case .quitHints:
            App.quitSelectedApp()
        case .fullscreenHints:
            App.toggleFullscreenSelectedWindow()
            App.refreshUi(true)
        case .hideHints:
            App.hideShowSelectedApp()
            App.refreshUi(true)
        }
    }

    static func switchToHintMode(_ mode: ChooserHintMode) {
        guard Preferences.windowHintsEnabled else { return }
        chooserHintMode = mode
        windowHintKeyBuffer = ""
        applyWindowHintLabels()
        syncWindowHintsChromeBanners()
        focusSelectedTileIfPossible()
        App.refreshUi(true)
        Windows.voiceOverWindow()
    }

    static func tryEnterChooserHintModeFromEvent(_ event: NSEvent) -> Bool {
        guard Preferences.windowHintsEnabled else { return false }
        guard event.type == .keyDown, !event.isARepeat else { return false }
        let pairs: [(String, ChooserHintMode)] = [
            ("focusWindowShortcut", .focusHints),
            ("minDeminWindowShortcut", .minimizeHints),
            ("closeWindowShortcut", .closeHints),
            ("quitAppShortcut", .quitHints),
            ("toggleFullscreenWindowShortcut", .fullscreenHints),
            ("hideShowAppShortcut", .hideHints),
        ]
        for (id, mode) in pairs {
            if id == "focusWindowShortcut" {
                continue
            }
            guard matchesPanelShortcutForModeEntry(event, id) else { continue }
            if chooserHintMode == mode {
                return true
            }
            switchToHintMode(mode)
            return true
        }
        return false
    }

    private static func matchesPanelShortcutForModeEntry(_ event: NSEvent, _ shortcutId: String) -> Bool {
        guard let shortcut = ControlsTab.shortcuts[shortcutId]?.shortcut else { return false }
        if shortcut.keyCode == .none || shortcut.carbonKeyCode != UInt32(event.keyCode) { return false }
        let holdModifiers = ControlsTab.shortcuts[Preferences.indexToName("holdShortcut", SwitcherSession.activeShortcutIndex)]?.shortcut.carbonModifierFlags.cleaned() ?? 0
        let eventModifiers = cocoaToCarbonFlags(event.modifierFlags).cleaned()
        let shortcutModifiers = shortcut.carbonModifierFlags.cleaned()
        return eventModifiers == shortcutModifiers || eventModifiers == (shortcutModifiers | holdModifiers)
    }

    private static func syncWindowHintLabelMap() {
        windowHintLabelAtIndex = Array(repeating: "", count: Windows.list.count)
        let visibleCount = (0..<Windows.list.count).filter { Windows.shouldDisplay(Windows.list[$0]) }.count
        let labels = WindowHintLabels.labels(for: visibleCount)
        var li = 0
        for i in 0..<Windows.list.count {
            guard Windows.shouldDisplay(Windows.list[i]) else { continue }
            if li < labels.count {
                windowHintLabelAtIndex[i] = labels[li]
            }
            li += 1
        }
    }

    private static func applyWindowHintLabels() {
        syncWindowHintLabelMap()
        for i in 0..<Windows.list.count {
            guard i < recycledViews.count else { break }
            let label = i < windowHintLabelAtIndex.count ? windowHintLabelAtIndex[i] : ""
            let show = Preferences.windowHintsEnabled && windowHintMode && !label.isEmpty
            recycledViews[i].updateWindowHintBadge(show ? label : nil)
        }
    }

    static func toggleSearchModeFromShortcut() {
        switch SearchModeResolver.toggle(mode: searchMode) {
            case .enterEditing: enableSearchEditing()
            case .disable: disableSearchMode()
        }
    }

    static func disableSearchMode() {
        MainThreadStall.step()
        guard SearchModeResolver.disable(mode: searchMode) == .exitToOff else { return }
        TilesPanel.shared.resetFrozenPosition()
        searchFieldYieldsToHints = false
        searchMode = .off
        clearHover()
        Windows.updateSearchQuery("")
        App.refreshUi(true)
        takeTheCaretFromTheField(focusingSelectedTile: true)
    }

    static func enableSearchEditing() {
        MainThreadStall.step()
        switch SearchModeResolver.enableEditing(mode: searchMode, canSearch: ProFeature.searchInSwitcher.attemptUse()) {
            case .placeCaretOnly:
                searchFieldYieldsToHints = false
                giveTheFieldTheCaret()
            case .enterEditing:
                SearchDiscoveryHint.shared.cancel()
                searchFieldYieldsToHints = false
                searchMode = .editing
                updateSearchFieldEditability()
                SwitcherSession.current?.forceDoNothingOnRelease = true
                clearHover()
                stopKeyRepeatTimers()
                App.refreshUi(true)
                giveTheFieldTheCaret()
            default:
                return
        }
    }

    /// The show-path twin of `endSearchSession`: making the field first responder ACTIVATES the system
    /// text-input context, the same synchronous XPC whose deactivation timed out for 3.0s in #5981. It runs
    /// a runloop turn late so the CoreAnimation transaction that reveals the panel commits first —
    /// `TilesPanel.show()` has only SET alpha at this point, so a stall here would keep the old frame on
    /// screen. Measured under 1ms on macOS 26.6.2; the deferral is for the tail, not the median.
    private static func giveTheFieldTheCaret() {
        DispatchQueue.main.async {
            guard searchMode == .editing, SwitcherSession.isActive else { return }
            giveTheFieldTheCaretNow()
        }
    }

    /// Until the deferred pass above runs, the field is not first responder and a typed key would go to the
    /// panel instead. It normally wins that race by a wide margin (measured 5-9ms, and 77ms on the first
    /// summon of a launch where the main thread is still busy discovering windows), but the user is waiting
    /// for this keystroke, so close the window rather than bet on it. A no-op once the field already has it:
    /// past that point the selection belongs to the user, and moving it is what broke ⌘A (#6019). See
    /// `SearchFieldEditing`.
    static func giveTheFieldTheCaretNow() {
        let intent = SearchFieldEditing.caretIntent(mode: searchMode, fieldOwnsCaret: fieldOwnsTheCaret())
        guard intent == .takeCaretAndCollapseToEnd else { return }
        TilesPanel.shared.makeFirstResponder(searchField)
        placeSearchCaretAtEnd()
    }

    private static func fieldOwnsTheCaret() -> Bool {
        guard let editor = searchField.currentEditor() else { return false }
        return TilesPanel.shared.firstResponder === editor
    }

    static func handleSearchEditingKeyDown(_ event: NSEvent) -> SearchKeyResult {
        let isPrintable = eventProducesText(event)
        if Preferences.windowHintsEnabled, Int(event.keyCode) == kVK_Tab {
            if searchFieldYieldsToHints {
                searchFieldYieldsToHints = false
                TilesPanel.shared.makeFirstResponder(searchField)
                placeSearchCaretAtEnd()
                syncSearchFieldTabHintToolTip()
                return .handled
            }
            searchFieldYieldsToHints = true
            focusSelectedTileIfPossible()
            syncSearchFieldTabHintToolTip()
            return .handled
        }
        let decision = SearchModeResolver.routeKey(
            hasMarkedText: hasMarkedText(),
            isMenuOpen: ContextMenuEvents.isMenuOpen,
            arrow: arrowCycleDirection(event.keyCode),
            isTab: Int(event.keyCode) == kVK_Tab,
            matchesShortcut: matchesAnyWhenActiveShortcut(event, isPrintable))
        switch decision {
            case .cycleSelection(let direction):
                App.cycleSelection(cycleToDirection(direction))
                return .handled
            case .handled: return .handled
            case .passToShortcuts: return .passToShortcuts
            case .passToField: return .passToField
        }
    }

    private static func arrowCycleDirection(_ keyCode: UInt16) -> CycleDirection? {
        switch Int(keyCode) {
            case kVK_LeftArrow: return .left
            case kVK_RightArrow: return .right
            case kVK_UpArrow: return .up
            case kVK_DownArrow: return .down
            default: return nil
        }
    }

    private static func cycleToDirection(_ direction: CycleDirection) -> Direction {
        switch direction {
            case .left: return .left
            case .right: return .right
            case .up: return .up
            case .down: return .down
        }
    }

    private static func configureNoWindowLabel() {
        noWindowLabel.textColor = .secondaryLabelColor
        noWindowLabel.font = .systemFont(ofSize: 13)
        noWindowLabel.alignment = .center
        noWindowLabel.isHidden = true
    }

    private static func configureHintChrome() {
        chooserBannerLabel.isEditable = false
        chooserBannerLabel.isBordered = false
        chooserBannerLabel.drawsBackground = false
        chooserBannerLabel.isSelectable = false
        chooserBannerLabel.alignment = .center
        chooserBannerLabel.lineBreakMode = .byWordWrapping
        chooserBannerLabel.maximumNumberOfLines = 0
        chooserBannerLabel.isHidden = true
        searchTabHintLabel.isEditable = false
        searchTabHintLabel.isBordered = false
        searchTabHintLabel.drawsBackground = false
        searchTabHintLabel.isHidden = true
        searchTabHintLabel.alignment = .natural
        searchTabHintLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        searchTabHintLabel.textColor = NSColor.secondaryLabelColor
        searchTabHintLabel.lineBreakMode = .byTruncatingTail
        searchTabHintLabel.maximumNumberOfLines = 1
    }

    private static func configureSearchField() {
        searchField.applySearchStyle()
        searchField.usesSingleLineMode = true
        searchField.target = Self.self
        searchField.action = #selector(Self.searchFieldChanged(_:))
        NotificationCenter.default.addObserver(forName: NSControl.textDidChangeNotification, object: searchField, queue: .main) { _ in
            updateSearchQuery(searchField.stringValue)
        }
        updateSearchFieldEditability()
    }

    @objc private static func searchFieldChanged(_ sender: NSSearchField) {
        updateSearchQuery(sender.stringValue)
    }

    private static func updateSearchQuery(_ query: String) {
        if (SwitcherSession.current?.searchQuery ?? "") == query { return }
        if !query.isEmpty { UsageStats.recordSearchIfFirst() }
        clearHover()
        Windows.updateSearchQuery(query)
        stopKeyRepeatTimers()
        App.refreshUi(true)
    }

    private static func clearHover() {
        guard let session = SwitcherSession.current, session.hoveredIndex != nil else { return }
        thumbnailOverView.resetHoveredWindow()
        TilesView.highlight(session.selectedIndex)
    }

    private static func stopKeyRepeatTimers() {
        let shortcutIndex = SwitcherSession.current?.shortcutIndex ?? 0
        KeyRepeatTimer.stopTimerForRepeatingKey(Preferences.indexToName("nextWindowShortcut", shortcutIndex))
        KeyRepeatTimer.stopTimerForRepeatingKey("previousWindowShortcut")
    }

    private static func focusSelectedTileIfPossible() {
        let index = SwitcherSession.current?.selectedIndex ?? 0
        guard index >= 0, index < TilesView.recycledViews.count else { return }
        let tile = TilesView.recycledViews[index]
        guard tile.window_ != nil, tile.window != nil else { return }
        TilesPanel.shared.makeFirstResponder(tile)
    }

    /// AppKit selects the whole content when a text field becomes first responder, so the keystroke that
    /// made us take the caret would REPLACE what is already in the field. Collapse to the end instead.
    /// Only ever runs on the turn we take the caret; see `giveTheFieldTheCaretNow`.
    private static func placeSearchCaretAtEnd() {
        guard let editor = searchField.currentEditor() else { return }
        editor.selectedRange = SearchFieldEditing.endOfText(length: searchField.stringValue.utf16.count)
    }

    static func hasMarkedText() -> Bool {
        (searchField.currentEditor() as? NSTextView)?.hasMarkedText() == true
    }

    /// While editing the search field, any when-active shortcut (close / minimize / quit / fullscreen /
    /// hide / focus / cancel / search) can be triggered by re-pressing the hold modifiers (e.g.
    /// Cmd+Option+W); a bare printable key still types into the field. `Preferences.staticShortcutKeys`
    /// is the single source of truth for the set. See `SearchModeResolver.editingShortcutMatch`.
    private static func matchesAnyWhenActiveShortcut(_ event: NSEvent, _ isPrintable: Bool) -> Bool {
        Preferences.staticShortcutKeys.contains { matchesShortcut(event, $0, isPrintable) }
    }

    private static func matchesShortcut(_ event: NSEvent, _ shortcutId: String, _ isPrintable: Bool) -> Bool {
        guard let shortcut = ControlsTab.shortcuts[shortcutId]?.shortcut else { return false }
        if shortcut.keyCode == .none || shortcut.carbonKeyCode != UInt32(event.keyCode) { return false }
        let shortcutIndex = SwitcherSession.current?.shortcutIndex ?? 0
        let holdModifiers = ControlsTab.shortcuts[Preferences.indexToName("holdShortcut", shortcutIndex)]?.shortcut.carbonModifierFlags.cleaned() ?? 0
        let eventModifiers = cocoaToCarbonFlags(event.modifierFlags).cleaned()
        let shortcutModifiers = shortcut.carbonModifierFlags.cleaned()
        let hasCommandModifier = (shortcutModifiers & (UInt32(cmdKey) | UInt32(controlKey))) != 0
        return SearchModeResolver.editingShortcutMatch(
            eventModifiers: eventModifiers,
            shortcutModifiers: shortcutModifiers,
            holdModifiers: holdModifiers,
            isPrintable: isPrintable,
            shortcutHasCommandModifier: hasCommandModifier)
    }

    /// Whether this key-down inserts text into the field (a letter / digit / punctuation / space) as
    /// opposed to a control key (Escape / Return / Tab / arrows / function keys). Lets a plain typed
    /// key beat a when-active shortcut bound to it. See `SearchModeResolver.editingShortcutMatch`.
    private static func eventProducesText(_ event: NSEvent) -> Bool {
        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else { return false }
        let v = scalar.value
        if v < 0x20 || v == 0x7F { return false }      // C0 control characters + delete
        if v >= 0xF700 && v <= 0xF8FF { return false } // arrows / function keys (NSEvent reserved range)
        return true
    }

    private static func updateSearchFieldEditability() {
        let editable = SearchModeResolver.isFieldEditable(searchMode)
        searchField.isEditable = editable
        searchField.isSelectable = editable
        if SwitcherSession.isActive {
            MainMenu.toggleEditMenu(editable)
        }
        syncSearchFieldTabHintToolTip()
    }

    private static func syncSearchFieldTabHintToolTip() {
        guard searchMode != .off, Preferences.windowHintsEnabled else {
            searchField.toolTip = nil
            searchTabHintLabel.isHidden = true
            return
        }
        searchField.toolTip = NSLocalizedString("search.tabHintWithWindowHints", comment: "")
        searchTabHintLabel.stringValue = searchFieldYieldsToHints
            ? NSLocalizedString("search.tabHintPressTabForSearch", comment: "")
            : NSLocalizedString("search.tabHintPressTabForHints", comment: "")
        searchTabHintLabel.isHidden = false
    }

    private static func chooserBannerChromeHeightForLayout(_ width: CGFloat) -> CGFloat {
        guard Preferences.windowHintsEnabled, width > 0 else { return chooserBannerMinHeight }
        syncWindowHintsChromeBanners()
        chooserBannerLabel.preferredMaxLayoutWidth = width
        let fitH = ceil(chooserBannerLabel.sizeThatFits(NSSize(width: width, height: 10_000)).height)
        chooserBannerCachedHeight = max(fitH, chooserBannerMinHeight)
        return chooserBannerCachedHeight
    }

    private static func hintBannerGapForLayout() -> CGFloat {
        windowHintMode ? hintBannerGapHint : hintBannerGapNormal
    }

    private static func hintBannerReservedHeight(_ width: CGFloat) -> CGFloat {
        guard Preferences.windowHintsEnabled else { return 0 }
        return chooserBannerChromeHeightForLayout(width) + hintBannerGapForLayout()
    }

    private static func syncWindowHintsChromeBanners() {
        guard Preferences.windowHintsEnabled else {
            chooserBannerLabel.isHidden = true
            return
        }
        chooserBannerLabel.isHidden = false
        chooserBannerLabel.attributedStringValue = chooserBannerCombinedAttributedLine()
    }

    private static func chooserBannerTitleFont() -> NSFont {
        NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    }

    private static func chooserBannerDetailFont() -> NSFont {
        NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1)
    }

    private static func chooserBannerCombinedAttributedLine() -> NSAttributedString {
        let titleFont = chooserBannerTitleFont()
        let detailFont = chooserBannerDetailFont()
        let shortcutFont = chooserBannerShortcutFont()
        var parts = [NSAttributedString]()
        parts.append(NSAttributedString(string: chooserLocalizedTitleForMode(chooserHintMode), attributes: [.font: titleFont, .foregroundColor: NSColor.labelColor]))
        parts.append(NSAttributedString(string: chooserLocalizedDetailForMode(chooserHintMode), attributes: [.font: detailFont, .foregroundColor: NSColor.secondaryLabelColor]))
        let shortcuts = chooserModeSwitchShortcutsAttributedLine()
        if shortcuts.length > 0 { parts.append(shortcuts) }
        if Preferences.shortcutStyle == .doNothingOnRelease {
            let d = Preferences.shortcutDisplayString("openSettingsFromSwitcherShortcut").trimmingCharacters(in: .whitespaces)
            let key = d.isEmpty ? "⌘," : d
            parts.append(ChooserBannerShortcutFormatting.attributedShortcutColonDescription(
                shortcutDisplay: key,
                description: NSLocalizedString("chooserMode.settingsShortcutLineDesc", comment: ""),
                font: shortcutFont))
        }
        if Preferences.arrowKeysEnabled {
            parts.append(NSAttributedString(string: NSLocalizedString("chooserMode.arrowKeysFooter", comment: ""), attributes: [.font: shortcutFont, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        let joined = ChooserBannerShortcutFormatting.joined(groups: parts, separator: chooserBannerLineSeparator, font: detailFont)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        let out = NSMutableAttributedString(attributedString: joined)
        out.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: out.length))
        return out
    }

    private static func chooserBannerShortcutFont() -> NSFont {
        NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 2)
    }

    private static func chooserLocalizedTitleForMode(_ mode: ChooserHintMode) -> String {
        switch mode {
        case .normal:
            return NSLocalizedString("chooserMode.title.normal", comment: "")
        case .focusHints: return NSLocalizedString("chooserMode.title.focusHints", comment: "")
        case .minimizeHints: return NSLocalizedString("chooserMode.title.minimizeHints", comment: "")
        case .closeHints: return NSLocalizedString("chooserMode.title.closeHints", comment: "")
        case .quitHints: return NSLocalizedString("chooserMode.title.quitHints", comment: "")
        case .fullscreenHints: return NSLocalizedString("chooserMode.title.fullscreenHints", comment: "")
        case .hideHints: return NSLocalizedString("chooserMode.title.hideHints", comment: "")
        }
    }

    private static func escKeyDisplayForBanner() -> String {
        if let v = LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: kVK_Escape)) {
            return String(describing: v)
        }
        return "Esc"
    }

    private static func chooserLocalizedDetailForMode(_ mode: ChooserHintMode) -> String {
        let esc = escKeyDisplayForBanner()
        switch mode {
        case .normal:
            let hintEnter = Preferences.shortcutDisplayString("enterHintModeFromNormalShortcut").trimmingCharacters(in: .whitespaces)
            let hintKey = hintEnter.isEmpty ? "—" : hintEnter
            return String(format: NSLocalizedString("chooserMode.detail.subtitle.normal", comment: ""), hintKey, esc)
        case .focusHints:
            return String(format: NSLocalizedString("chooserMode.detail.subtitle.focusHints", comment: ""), esc)
        case .minimizeHints:
            return String(format: NSLocalizedString("chooserMode.detail.subtitle.minimizeHints", comment: ""), esc)
        case .closeHints:
            return String(format: NSLocalizedString("chooserMode.detail.subtitle.closeHints", comment: ""), esc)
        case .quitHints:
            return String(format: NSLocalizedString("chooserMode.detail.subtitle.quitHints", comment: ""), esc)
        case .fullscreenHints:
            return String(format: NSLocalizedString("chooserMode.detail.subtitle.fullscreenHints", comment: ""), esc)
        case .hideHints:
            return String(format: NSLocalizedString("chooserMode.detail.subtitle.hideHints", comment: ""), esc)
        }
    }

    private static func chooserModeSwitchDescFocus() -> String {
        switch chooserHintMode {
        case .normal:
            return NSLocalizedString("chooserMode.modeSwitchDesc.focus", comment: "")
        case .focusHints:
            return NSLocalizedString("chooserMode.modeSwitchDesc.focusVerb.focusHints", comment: "")
        case .minimizeHints:
            return NSLocalizedString("chooserMode.modeSwitchDesc.focusVerb.minimizeHints", comment: "")
        case .closeHints:
            return NSLocalizedString("chooserMode.modeSwitchDesc.focusVerb.closeHints", comment: "")
        case .quitHints:
            return NSLocalizedString("chooserMode.modeSwitchDesc.focusVerb.quitHints", comment: "")
        case .fullscreenHints:
            return NSLocalizedString("chooserMode.modeSwitchDesc.focusVerb.fullscreenHints", comment: "")
        case .hideHints:
            return NSLocalizedString("chooserMode.modeSwitchDesc.focusVerb.hideHints", comment: "")
        }
    }

    private static func attributedEnterFocusHintFromActionModesBannerSegmentIfNeeded(font: NSFont) -> NSAttributedString? {
        switch chooserHintMode {
        case .minimizeHints, .closeHints, .quitHints, .hideHints:
            let d = Preferences.shortcutDisplayString("enterHintModeFromNormalShortcut").trimmingCharacters(in: .whitespaces)
            guard !d.isEmpty else { return nil }
            let desc = NSLocalizedString("chooserMode.modeSwitchDesc.enterFocusFromActionModes", comment: "")
            return ChooserBannerShortcutFormatting.attributedShortcutColonDescription(shortcutDisplay: d, description: desc, font: font)
        default:
            return nil
        }
    }

    private static func chooserModeSwitchShortcutsAttributedLine() -> NSAttributedString {
        let font = chooserBannerShortcutFont()
        var groups = [NSAttributedString]()
        if let seg = attributedEnterFocusHintFromActionModesBannerSegmentIfNeeded(font: font) {
            groups.append(seg)
        }
        let pairs: [(String, String)] = [
            ("focusWindowShortcut", chooserModeSwitchDescFocus()),
            ("minDeminWindowShortcut", NSLocalizedString("chooserMode.modeSwitchDesc.minimize", comment: "")),
            ("closeWindowShortcut", NSLocalizedString("chooserMode.modeSwitchDesc.close", comment: "")),
            ("quitAppShortcut", NSLocalizedString("chooserMode.modeSwitchDesc.quit", comment: "")),
            ("toggleFullscreenWindowShortcut", NSLocalizedString("chooserMode.modeSwitchDesc.fullscreen", comment: "")),
            ("hideShowAppShortcut", NSLocalizedString("chooserMode.modeSwitchDesc.hide", comment: "")),
        ]
        for (id, desc) in pairs {
            let d = Preferences.shortcutDisplayString(id).trimmingCharacters(in: .whitespaces)
            guard !d.isEmpty else { continue }
            groups.append(ChooserBannerShortcutFormatting.attributedShortcutColonDescription(shortcutDisplay: d, description: desc, font: font))
        }
        return ChooserBannerShortcutFormatting.joined(groups: groups, separator: chooserBannerLineSeparator, font: font)
    }

    /// A title label is always drawn on one line, so its height is a property of the FONT and of nothing
    /// else. Measuring it off a tile's own label made it a property of that window's title instead:
    /// `NSCell.cellSize.height` grows by one line height per line break in the string, so a single window
    /// titled with a multi-line string made every tile in the grid that much taller and pushed the
    /// thumbnails down inside them (#6010). `WindowTitle` keeps such a string out of the model; this keeps
    /// the metric out of reach of whatever does get in.
    private static let labelHeightProbe = TileTitleView(font: Appearance.font)

    static func labelLineHeight() -> CGFloat {
        labelHeightProbe.font = Appearance.font
        labelHeightProbe.stringValue = "Ag"
        return labelHeightProbe.cell!.cellSize.height
    }

    static func updateCachedSizes() {
        guard let firstView = TilesView.recycledViews.first else { return }
        layoutCache.labelHeight = labelLineHeight()
        let iconCellSize = firstView.statusIcons.iconCellSize
        layoutCache.iconWidth = iconCellSize.width
        layoutCache.iconHeight = iconCellSize.height
        layoutCache.comfortableReadabilityWidth = TileView.widthOfComfortableReadability()
        TileFontIconView.symbolCache.removeAll()
        let spaceNumberStrings = (0...19).map { StatusIconsView.symbolForSpace($0) }
        TileFontIconView.warmCaches(symbols: [.circledPlusSign, .circledMinusSign, .circledSlashSign, .circledStar], extraStrings: spaceNumberStrings, size: Appearance.fontHeight, color: Appearance.fontColor)
    }

    static func updateBackgroundView() {
        let kind = requiredEffectViewKind()
        contentView = cachedEffectView(for: kind)
        currentEffectViewKind = kind
        let host = contentView.hostView
        scrollView?.removeFromSuperview()
        scrollView = ScrollView()
        if searchMode != .off {
            host.addSubview(searchField)
        } else {
            searchField.removeFromSuperview()
        }
        host.addSubview(scrollView)
        host.addSubview(noWindowLabel)
        host.addSubview(chooserBannerLabel)
        host.addSubview(searchTabHintLabel)
        if SnapSession.isActive {
            host.addSubview(snapLayoutPanel)
        }
    }

    static func swapBackgroundViewIfNeeded() {
        guard contentView != nil else { return }
        let desired = requiredEffectViewKind()
        guard desired != currentEffectViewKind else { return }
        let newView = cachedEffectView(for: desired)
        currentEffectViewKind = desired
        let host = newView.hostView
        if searchField.superview === contentView.hostView {
            host.addSubview(searchField)
        }
        host.addSubview(scrollView)
        host.addSubview(noWindowLabel)
        host.addSubview(chooserBannerLabel)
        host.addSubview(searchTabHintLabel)
        if SnapSession.isActive {
            host.addSubview(snapLayoutPanel)
        }
        contentView = newView
        TilesPanel.shared.contentView = newView
    }

    private static func cachedEffectView(for kind: EffectViewKind) -> EffectView {
        if let cached = cachedEffectViews[kind] {
            cached.updateAppearance()
            return cached
        }
        let view = makeEffectView(for: kind)
        cachedEffectViews[kind] = view
        return view
    }

    static func reset() {
        // it would be nicer to remove this whole "reset" logic, and instead update each component to check Appearance properties before showing
        // Maybe in some Appkit willDraw() function that triggers before drawing it
        NSScreen.updatePreferred()
        Appearance.update()
        // thumbnails are captured continuously. They will pick up the new size on the next cycle
        TilesPanel.updateMaxPossibleThumbnailSize()
        // app icons are captured once at launch; we need to manually update them if needed
        let old = TilesPanel.maxPossibleAppIconSize.width
        TilesPanel.updateMaxPossibleAppIconSize()
        if old != TilesPanel.maxPossibleAppIconSize.width {
            Applications.updateAppIcons()
        }
        updateBackgroundView()
        TilesPanel.shared.contentView = contentView
        // Reuse the pooled tiles instead of reallocating them: recreating freed the tooltip-owning
        // subviews while NSToolTipManager still referenced them, crashing when an in-flight tooltip
        // timer fired. reapplyAppearance() refreshes the construction-time appearance state in place.
        for view in TilesView.recycledViews {
            view.reapplyAppearance()
        }
        thumbnailUnderLayer = TileUnderLayer()
        thumbnailOverView = TileOverView()
        thumbnailOverView.scrollView = scrollView
        lastRowSignature.removeAll()
        cachedSearchBarHeight = nil
        Self.updateCachedSizes()
    }

    static func highlight(_ indexInRecycledViews: Int) {
        guard indexInRecycledViews >= 0, indexInRecycledViews < recycledViews.count else { return }
        let view = recycledViews[indexInRecycledViews]
        view.indexInRecycledViews = indexInRecycledViews
        guard view.frame != .zero else { return }
        view.drawHighlight()
        let underLayer = TilesView.thumbnailUnderLayer
        let selectedIndex = SwitcherSession.current?.selectedIndex ?? 0
        guard selectedIndex >= 0, selectedIndex < recycledViews.count else { return }
        let focusedView = recycledViews[selectedIndex]
        let hoveredView = SwitcherSession.current?.hoveredIndex.flatMap { $0 >= 0 && $0 < recycledViews.count ? recycledViews[$0] : nil }
        underLayer.updateHighlight(
            focusedView: focusedView.frame != .zero ? focusedView : nil,
            hoveredView: hoveredView != focusedView && hoveredView?.frame != .zero ? hoveredView : nil
        )
    }

    static func nextRow(_ direction: Direction, allowWrap: Bool = true) -> [TileView]? {
        let step = direction == .down ? 1 : -1
        if let currentRow = Windows.selectedWindow()?.rowIndex {
            var nextRow = currentRow + step
            if nextRow >= rows.count {
                if allowWrap {
                    nextRow = nextRow % rows.count
                } else {
                    return nil
                }
            } else if nextRow < 0 {
                if allowWrap {
                    nextRow = rows.count + nextRow
                } else {
                    return nil
                }
            }
            if ((step > 0 && nextRow < currentRow) || (step < 0 && nextRow > currentRow)) &&
                   (ATShortcut.lastEventIsARepeat || !KeyRepeatTimer.timerIsSuspended) {
                return nil
            }
            return rows[nextRow]
        }
        return nil
    }

    static func navigateUpOrDown(_ direction: Direction, allowWrap: Bool = true) {
        let selectedIndex = SwitcherSession.current?.selectedIndex ?? 0
        guard selectedIndex < TilesView.recycledViews.count else { return }
        let focusedViewFrame = TilesView.recycledViews[selectedIndex].frame
        let originCenter = NSMidX(focusedViewFrame)
        guard let targetRow = nextRow(direction, allowWrap: allowWrap), !targetRow.isEmpty else { return }
        let leftSide = originCenter < NSMidX(contentView.frame)
        let leadingSide = App.shared.userInterfaceLayoutDirection == .leftToRight ? leftSide : !leftSide
        let iterable = leadingSide ? targetRow : targetRow.reversed()
        guard let targetView = iterable.first(where: {
            if App.shared.userInterfaceLayoutDirection == .leftToRight {
                return leadingSide ? NSMaxX($0.frame) > originCenter : NSMinX($0.frame) < originCenter
            }
            return leadingSide ? NSMinX($0.frame) < originCenter : NSMaxX($0.frame) > originCenter
        }) ?? iterable.last else { return }
        guard let targetIndex = TilesView.recycledViews.firstIndex(of: targetView) else { return }
        SwitcherSession.current?.performUserSelection {
            Windows.updateSelectedAndHoveredWindowIndex(targetIndex)
        }
    }

    static func updateItemsAndLayout(_ preservedScrollOrigin: CGPoint?) {
        var widthMax = TilesPanel.maxThumbnailsWidth().rounded()
        if Preferences.effectiveAppearanceSize(SwitcherSession.activeShortcutIndex) == .auto {
            resolveAutoSize(widthMax)
            Self.updateCachedSizes()
            widthMax = TilesPanel.maxThumbnailsWidth().rounded()
        }
        if let (maxX, maxY, labelHeight, rowSignature) = layoutTileViews(widthMax) {
            layoutParentViews(maxX, widthMax, maxY, labelHeight)
            centerRows(TilesView.thumbnailsWidth)
            if rowSignature != lastRowSignature {
                for row in rows {
                    for (j, view) in row.enumerated() {
                        view.numberOfViewsInRow = row.count
                        view.isFirstInRow = j == 0
                        view.isLastInRow = j == row.count - 1
                        view.indexInRow = j
                    }
                }
                lastRowSignature = rowSignature
            }
            highlightStartView()
            applyWindowHintLabels()
            if let preservedScrollOrigin {
                restoreScrollOrigin(preservedScrollOrigin)
            }
        }
    }

    static func currentScrollOrigin() -> CGPoint {
        return scrollView.contentView.bounds.origin
    }

    private static func restoreScrollOrigin(_ scrollOrigin: CGPoint) {
        guard let documentView = scrollView.documentView else { return }
        let visibleSize = scrollView.contentView.bounds.size
        let documentSize = documentView.frame.size
        let maxX = max(0, documentSize.width - visibleSize.width)
        let maxY = max(0, documentSize.height - visibleSize.height)
        let clampedOrigin = CGPoint(x: min(max(0, scrollOrigin.x), maxX), y: min(max(0, scrollOrigin.y), maxY))
        scrollView.contentView.scroll(to: clampedOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private static func resolveAutoSize(_ widthMax: CGFloat) {
        let searchReservedHeight: CGFloat = (searchMode == .off ? 0 : searchBarHeight() + 10) + hintBannerReservedHeight(widthMax)
        let heightMax = max(0, TilesPanel.maxThumbnailsHeight() - searchReservedHeight)
        _ = TileGridLayout.firstSizeThatFits([AppearanceSizePreference.large, .medium, .small], heightMax: heightMax) { size in
            Appearance.applySize(size)
            Self.updateCachedSizes()
            return dryRunLayoutTileViews(widthMax)
        }
    }

    private static func dryRunLayoutTileViews(_ widthMax: CGFloat) -> CGFloat {
        let height = TileView.height(Self.layoutCache.labelHeight)
        let tiles = fillTiles(height).tiles
        return TileGridLayout.compute(gridInput(tiles, height, widthMax)).maxY
    }

    /// Puts this render's window on every recycled tile that has one, and releases the images the rest are
    /// still holding. Returns the tiles that will be placed, in model order, and whether the session ended
    /// half way — a caller that is about to commit a layout has nothing to commit in that case.
    private static func fillTiles(_ height: CGFloat) -> (tiles: [(index: Int, view: TileView)], aborted: Bool) {
        var tiles = [(index: Int, view: TileView)]()
        for index in 0..<TilesView.recycledViews.count {
            guard SwitcherSession.isActive else { return (tiles, true) }
            let view = TilesView.recycledViews[index]
            guard index < Windows.list.count else {
                // release images and stale window references from unused recycledViews; they take lots of RAM
                view.thumbnail.releaseImage()
                view.appIcon.releaseImage()
                view.window_ = nil
                continue
            }
            let window = Windows.list[index]
            guard Windows.shouldDisplay(window) else {
                view.frame = .zero
                continue
            }
            view.updateRecycledCellWithNewContent(window, index, height)
            tiles.append((index, view))
        }
        return (tiles, false)
    }

    private static func gridInput(_ tiles: [(index: Int, view: TileView)], _ height: CGFloat, _ widthMax: CGFloat) -> TileGridLayout.Input {
        TileGridLayout.Input(widths: tiles.map { $0.view.frame.size.width }, tileHeight: height, widthMax: widthMax,
            padding: Appearance.interCellPadding,
            isLeftToRight: App.shared.userInterfaceLayoutDirection == .leftToRight)
    }

    private static func layoutTileViews(_ widthMax: CGFloat) -> (CGFloat, CGFloat, CGFloat, [Int])? {
        let labelHeight = Self.layoutCache.labelHeight
        let height = TileView.height(labelHeight)
        let filled = fillTiles(height)
        guard !filled.aborted else { return nil }
        let tiles = filled.tiles
        let layout = TileGridLayout.compute(gridInput(tiles, height, widthMax))
        for (position, tile) in tiles.enumerated() {
            tile.view.frame.origin = layout.origins[position]
        }
        rows = layout.rows.map { $0.map { tiles[$0].view } }
        for (rowIndex, row) in layout.rows.enumerated() {
            for position in row { Windows.list[tiles[position].index].rowIndex = rowIndex }
        }
        let newViews = tiles.map { $0.view }
        let rowSignature = tiles.map { $0.index }
        let maxX = layout.maxX
        let maxY = layout.maxY
        scrollView.documentView!.subviews = newViews
        scrollView.documentView!.addSubview(thumbnailOverView)
        thumbnailOverView.scrollView = scrollView
        let docLayer = scrollView.documentView!.layer!
        if thumbnailUnderLayer.superlayer !== docLayer {
            docLayer.insertSublayer(thumbnailUnderLayer, at: 0)
        }
        return (maxX, maxY, labelHeight, rowSignature)
    }

    private static func layoutParentViews(_ maxX: CGFloat, _ widthMax: CGFloat, _ maxY: CGFloat, _ labelHeight: CGFloat) {
        let searchBarHeight = searchBarHeight()
        let searchBottomPadding = CGFloat(10)
        let hintReserved = hintBannerReservedHeight(widthMax)
        let searchRowReserved = searchMode == .off ? 0 : searchBarHeight + searchBottomPadding
        let searchReservedHeight = searchRowReserved + hintReserved
        let heightMax = max(0, TilesPanel.maxThumbnailsHeight() - searchReservedHeight)
        let minSearchWidth = min(widthMax, 320)
        let minWidth = min(widthMax, 320)
        TilesView.thumbnailsWidth = max(min(maxX, widthMax), searchMode == .off ? (maxX == 0 ? minWidth : 0) : minWidth)
        TilesView.thumbnailsHeight = min(maxY, heightMax)
        let appIconsBottomViewportPadding = appIconsBottomViewportPadding(maxY, heightMax, labelHeight)
        let frameWidth = TilesView.thumbnailsWidth + Appearance.windowPadding * 2
        var frameHeight = TilesView.thumbnailsHeight + Appearance.windowPadding * 2 + searchReservedHeight
        let originX = Appearance.windowPadding
        var originY = Appearance.windowPadding
        if Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) == .appIcons {
            // If there is title under the icon on the last line, the height of the title needs to be subtracted.
            frameHeight = frameHeight - Appearance.intraCellPadding - labelHeight
            originY = originY - Appearance.intraCellPadding - labelHeight
        }
        contentView.frame.size = NSSize(width: frameWidth, height: frameHeight)
        let host = contentView.hostView
        if host !== contentView {
            host.frame = CGRect(origin: .zero, size: NSSize(width: frameWidth, height: frameHeight))
        }
        let scrollHeight = max(0, min(maxY, heightMax) - appIconsBottomViewportPadding * 2)
        scrollView.frame.size = NSSize(width: TilesView.thumbnailsWidth, height: scrollHeight)
        scrollView.frame.origin = CGPoint(x: originX, y: originY + appIconsBottomViewportPadding * 2)
        scrollView.contentView.frame.size = scrollView.frame.size
        let showWindowHintsChrome = Preferences.windowHintsEnabled
        if searchMode != .off {
            if searchField.superview !== host {
                host.addSubview(searchField)
            }
            let searchWidth = minSearchWidth
            let labelMaxWidth = max(CGFloat(72), min(CGFloat(220), TilesView.thumbnailsWidth - searchWidth - searchTabHintGap - 8))
            let rowContentWidth = searchWidth + searchTabHintGap + labelMaxWidth
            let searchX = originX + (TilesView.thumbnailsWidth - rowContentWidth) * 0.5
            let searchY = frameHeight - Appearance.windowPadding - searchBarHeight - hintReserved
            searchField.frame.size = NSSize(width: searchWidth, height: searchBarHeight)
            searchField.frame.origin = CGPoint(x: searchX, y: searchY)
            searchField.layoutSubtreeIfNeeded()
            searchTabHintLabel.isHidden = !Preferences.windowHintsEnabled
            let hintX = searchX + searchWidth + searchTabHintGap
            if Preferences.windowHintsEnabled {
                syncSearchFieldTabHintToolTip()
                searchTabHintLabel.font = searchField.font
                searchTabHintLabel.preferredMaxLayoutWidth = labelMaxWidth
                let hintW = labelMaxWidth
                let hintFitH = ceil(searchTabHintLabel.sizeThatFits(NSSize(width: hintW, height: 10_000)).height)
                let hintH = max(hintFitH, searchBarHeight)
                let alignRect = searchField.alignmentRect(forFrame: searchField.bounds)
                let alignInParent = searchField.convert(alignRect, to: searchField.superview)
                let hintY = alignInParent.midY - hintH / 2
                searchTabHintLabel.frame = CGRect(x: hintX, y: hintY, width: hintW, height: hintH)
            } else {
                searchTabHintLabel.frame = CGRect(x: hintX, y: searchY, width: labelMaxWidth, height: searchBarHeight)
            }
        } else if searchField.superview != nil {
            searchField.removeFromSuperview()
            searchTabHintLabel.isHidden = true
        }
        if showWindowHintsChrome {
            let bannerH = chooserBannerChromeHeightForLayout(TilesView.thumbnailsWidth)
            let bannerGap = hintBannerGapForLayout()
            let bannerY: CGFloat
            if searchMode == .off {
                bannerY = frameHeight - Appearance.windowPadding - bannerH
            } else {
                let searchY = frameHeight - Appearance.windowPadding - searchBarHeight - hintReserved
                bannerY = searchY + searchBarHeight + bannerGap
            }
            chooserBannerLabel.frame = CGRect(x: originX, y: bannerY, width: TilesView.thumbnailsWidth, height: bannerH)
        } else {
            chooserBannerLabel.isHidden = true
        }
        if searchMode != .off, !Preferences.windowHintsEnabled {
            syncSearchFieldTabHintToolTip()
        }
        if App.shared.userInterfaceLayoutDirection == .rightToLeft {
            let croppedWidth = TileGridLayout.rightToLeftCropOffset(layoutWidth: widthMax, viewportWidth: TilesView.thumbnailsWidth)
            scrollView.documentView!.subviews.forEach { $0.frame.origin.x -= croppedWidth }
        }
        scrollView.documentView!.frame.size = NSSize(width: max(maxX, TilesView.thumbnailsWidth), height: maxY)
        let docSize = scrollView.documentView!.frame.size
        thumbnailOverView.frame = CGRect(origin: .zero, size: docSize)
        thumbnailUnderLayer.frame = CGRect(origin: .zero, size: docSize)
        let isEmpty = maxX == 0
        noWindowLabel.isHidden = !isEmpty
        if isEmpty {
            noWindowLabel.sizeToFit()
            let labelX = originX + (TilesView.thumbnailsWidth - noWindowLabel.frame.width) * 0.5
            let labelY = scrollView.frame.origin.y + (scrollView.frame.height - noWindowLabel.frame.height) * 0.5
            noWindowLabel.frame.origin = CGPoint(x: labelX, y: labelY)
        }
        if SnapSession.isActive {
            scrollView.isHidden = true
            noWindowLabel.isHidden = true
            layoutSnapLayoutPanel()
            updateChooserBannerForSnapMode()
        }
    }

    private static var cachedSearchBarHeight: CGFloat?

    private static func searchBarHeight() -> CGFloat {
        if let cached = cachedSearchBarHeight { return cached }
        let fitting = searchField.fittingSize.height
        let height = fitting > 0 ? ceil(fitting) : ceil(searchField.cell?.cellSize.height ?? 30)
        cachedSearchBarHeight = height
        return height
    }

    private static func appIconsBottomViewportPadding(_ maxY: CGFloat, _ heightMax: CGFloat, _ labelHeight: CGFloat) -> CGFloat {
        guard Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) == .appIcons, maxY > heightMax else { return 0 }
        return max(0, Appearance.windowPadding - labelHeight)
    }

    static func centerRows(_ maxX: CGFloat) {
        let offsets = TileGridLayout.centeringOffsets(rowWidths: rows.map { $0.map { $0.frame.size.width } },
            padding: Appearance.interCellPadding, within: maxX)
        let sign: CGFloat = App.shared.userInterfaceLayoutDirection == .leftToRight ? 1 : -1
        for (rowIndex, row) in rows.enumerated() {
            guard SwitcherSession.isActive else { return }
            guard offsets[rowIndex] > 0 else { continue }
            for view in row { view.frame.origin.x += sign * offsets[rowIndex] }
        }
    }

    private static func highlightStartView() {
        let session = SwitcherSession.current
        if Windows.selectedWindow() != nil {
            TilesView.highlight(session?.selectedIndex ?? 0)
        } else {
            thumbnailUnderLayer.updateHighlight(focusedView: nil, hoveredView: nil)
            thumbnailOverView.hideWindowControls()
        }
        if let hoveredWindowIndex = session?.hoveredIndex,
           hoveredWindowIndex >= 0,
           hoveredWindowIndex < Windows.list.count,
           Windows.shouldDisplay(Windows.list[hoveredWindowIndex]) {
            TilesView.highlight(hoveredWindowIndex)
            if thumbnailOverView.isShowingWindowControls {
                thumbnailOverView.showWindowControls(for: TilesView.recycledViews[hoveredWindowIndex])
            }
        } else {
            thumbnailOverView.hideWindowControls()
        }
    }

    static func windowIdsInViewport() -> Set<CGWindowID> {
        guard let scrollView else { return [] }
        let visibleBounds = scrollView.documentVisibleRect
        var ids = Set<CGWindowID>()
        let count = min(recycledViews.count, Windows.list.count)
        for index in 0..<count {
            let frame = recycledViews[index].frame
            if frame == .zero { continue } // filtered-out window, not "off-screen"
            if visibleBounds.intersects(frame), let wid = Windows.list[index].cgWindowId {
                ids.insert(wid)
            }
        }
        return ids
    }

    static func clearNeedsLayout() {
        var views = [NSView]()
        if let contentView { views.append(contentView as NSView) }
        views.append(noWindowLabel)
        views.append(chooserBannerLabel)
        views.append(searchTabHintLabel)
        if let scrollView {
            views.append(scrollView)
            views.append(scrollView.contentView)
            if let documentView = scrollView.documentView { views.append(documentView) }
        }
        for view in views {
            view.needsLayout = false
            view.needsDisplay = false
            view.needsUpdateConstraints = false
        }
    }

    struct LayoutCache {
        var labelHeight = CGFloat(0)
        var iconWidth = CGFloat(0)
        var iconHeight = CGFloat(0)
        var comfortableReadabilityWidth: CGFloat?
    }

    
}

class ScrollView: NSScrollView {
    // overriding scrollWheel() turns this false; we force it to be true to enable responsive scrolling
    override class var isCompatibleWithResponsiveScrolling: Bool { true }

    var isCurrentlyScrolling = false

    convenience init() {
        self.init(frame: .zero)
        documentView = TilesDocumentView(frame: .zero)
        documentView!.wantsLayer = true
        drawsBackground = false
        hasVerticalScroller = true
        verticalScrollElasticity = .none
        scrollerStyle = .overlay
        scrollerKnobStyle = .light
        horizontalScrollElasticity = .none
        usesPredominantAxisScrolling = true
        observeScrollingEvents()
    }

    private func observeScrollingEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(scrollingStarted), name: NSScrollView.willStartLiveScrollNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scrollingEnded), name: NSScrollView.didEndLiveScrollNotification, object: nil)
    }

    @objc private func scrollingStarted() { isCurrentlyScrolling = true }
    @objc private func scrollingEnded() { isCurrentlyScrolling = false }

    /// holding shift and using the scrolling wheel will generate a horizontal movement
    /// shift can be part of shortcuts so we force shift scrolls to be vertical
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) && event.scrollingDeltaY == 0 {
            let cgEvent = event.cgEvent!
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: cgEvent.getDoubleValueField(.scrollWheelEventDeltaAxis2))
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: 0)
            super.scrollWheel(with: NSEvent(cgEvent: cgEvent)!)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

class TilesDocumentView: FlippedView {
    private static let dragAndDropTimerDelay = TimeInterval(2)
    private static let dragAndDropTimerResetDistance = CGFloat(5)

    private weak var dragTarget: TileView?
    private var lastDragLocation: NSPoint?
    private var timerResetLocation: NSPoint?
    private var dragAndDropTimer: Timer?

    // periphery:ignore - AppKit private overrides, found by the ObjC runtime rather than called
    @objc func _windowChangedKeyState() {}
    // periphery:ignore - AppKit private overrides, found by the ObjC runtime rather than called
    @objc func _layoutSubtreeWithOldSize(_ oldSize: NSSize) {}

    override func wantsPeriodicDraggingUpdates() -> Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // we only handle URLs (i.e. not text, image, or other draggable things)
        registerForDraggedTypes([NSPasteboard.PasteboardType(UTType.url.identifier)])
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let location = sender.draggingLocation
        lastDragLocation = location
        return dragOperation(location)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let location = sender.draggingLocation
        if location != lastDragLocation { lastDragLocation = location }
        return dragOperation(location)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        resetDraggingState(true)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { resetDraggingState(false) }
        let target = targetView(sender.draggingLocation) ?? dragTarget
        let appUrl = target?.window_?.application.bundleURL
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]) ?? []
        guard DragAndDropResolver.canDrop(hasTarget: target != nil, hasWindow: target?.window_ != nil, hasAppBundleURL: appUrl != nil, urlCount: urls.count),
              let appUrl else { return false }
        // `openApplication` reports the launch outcome on a background queue, long after AppKit
        // needs this return value. So the drop is accepted on the guard above, and a failed launch
        // is only logged.
        NSWorkspace.shared.open(urls, withApplicationAt: appUrl, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { Logger.error { "drag-and-drop failed to open urls: \(error)" } }
        }
        App.hideUi()
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        resetDraggingState(false)
    }

    private func dragOperation(_ location: NSPoint) -> NSDragOperation {
        let target = targetView(location)
        let pastDeadzone = target != nil && (window.map { CursorEvents.isAllowedToReactToPointerMovement($0.convertPoint(toScreen: location)) } ?? false)
        let decision = DragAndDropResolver.dragOver(
            hasTarget: target != nil,
            pastDeadzone: pastDeadzone,
            targetChanged: dragTarget !== target,
            movedBeyondResetRadius: DragAndDropResolver.movedBeyondResetRadius(from: timerResetLocation, to: location, resetRadius: Self.dragAndDropTimerResetDistance))
        switch decision {
        case .noTarget:
            resetDraggingState(true)
            return []
        case .inDeadzone:
            return .link
        case .track(let restartTimer):
            if let target {
                dragTarget = target
                if restartTimer { restartDraggingTimer(location) }
                target.mouseMovedCallback()
            }
            return .link
        }
    }

    private func restartDraggingTimer(_ location: NSPoint) {
        timerResetLocation = location
        dragAndDropTimer?.invalidate()
        dragAndDropTimer = Timer(timeInterval: Self.dragAndDropTimerDelay, repeats: false, block: { [weak self] _ in
            guard let self, let dragTarget = self.dragTarget else { return }
            dragTarget.mouseUpCallback()
        })
        dragAndDropTimer?.tolerance = 0.2
        if let dragAndDropTimer { RunLoop.main.add(dragAndDropTimer, forMode: .common) }
    }

    func cancelDraggingTimer() {
        dragAndDropTimer?.invalidate()
        dragAndDropTimer = nil
    }

    private func resetDraggingState(_ resetHoveredWindow: Bool) {
        lastDragLocation = nil
        dragTarget = nil
        timerResetLocation = nil
        dragAndDropTimer?.invalidate()
        dragAndDropTimer = nil
        if resetHoveredWindow { TilesView.thumbnailOverView.resetHoveredWindow() }
    }

    private func targetView(_ location: NSPoint) -> TileView? {
        let overlay = TilesView.thumbnailOverView
        return overlay.findTarget(overlay.convert(location, from: nil))
    }
}

fileprivate enum ChooserBannerShortcutFormatting {
    private static let modifierCharacters: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]

    static func splitDisplayIntoKeySegments(_ display: String) -> [String] {
        let s = display.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return [] }
        var i = s.startIndex
        var segments = [String]()
        while i < s.endIndex, modifierCharacters.contains(s[i]) {
            segments.append(String(s[i]))
            i = s.index(after: i)
        }
        let rest = String(s[i...]).trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty {
            segments.append(rest)
        }
        return segments
    }

    static func attributedShortcutKeyDisplay(_ display: String, font: NSFont) -> NSAttributedString {
        let segments = splitDisplayIntoKeySegments(display)
        if segments.isEmpty {
            return NSAttributedString(string: display, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        let result = NSMutableAttributedString()
        let sep = NSAttributedString(string: " + ", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        let bg = NSColor.controlBackgroundColor
        for (idx, seg) in segments.enumerated() {
            if idx > 0 { result.append(sep) }
            result.append(NSAttributedString(string: seg, attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: bg,
            ]))
        }
        return result
    }

    static func attributedShortcutColonDescription(shortcutDisplay: String, description: String, font: NSFont) -> NSAttributedString {
        let keys = attributedShortcutKeyDisplay(shortcutDisplay, font: font)
        let desc = NSAttributedString(string: ": \(description)", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        let combined = NSMutableAttributedString()
        combined.append(keys)
        combined.append(desc)
        return combined
    }

    static func joined(groups: [NSAttributedString], separator: String, font: NSFont) -> NSAttributedString {
        let sep = NSAttributedString(string: separator, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        let out = NSMutableAttributedString()
        for (i, g) in groups.enumerated() {
            if i > 0 { out.append(sep) }
            out.append(g)
        }
        return out
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}


enum Direction {
    case right
    case left
    case leading
    case trailing
    case up
    case down

    func step() -> Int {
        if self == .left {
            return App.shared.userInterfaceLayoutDirection == .leftToRight ? -1 : 1
        } else if self == .right {
            return App.shared.userInterfaceLayoutDirection == .leftToRight ? 1 : -1
        }
        return self == .leading ? 1 : -1
    }
}
