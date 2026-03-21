import Cocoa
import ShortcutRecorder

class KeyboardEventsTestable {
    static var globalShortcutsIds: [String: Int] {
        var ids = [String: Int]()
        (0..<Preferences.maxShortcutCount).forEach { ids[Preferences.indexToName("nextWindowShortcut", $0)] = $0 }
        (0..<Preferences.maxShortcutCount).forEach { ids[Preferences.indexToName("holdShortcut", $0)] = Preferences.maxShortcutCount + $0 }
        return ids
    }
}

@discardableResult
func handleKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool, _ event: NSEvent? = nil) -> Bool {
    if let event, event.type == .keyDown, App.appIsBeingUsed, TilesPanel.shared.isKeyWindow,
       !event.isARepeat,
       matchesActivePanelShortcut(event, "dismissSwitcherShortcut") {
        App.hideUi()
        return true
    }
    if let event, event.type == .keyDown, App.appIsBeingUsed, TilesPanel.shared.isKeyWindow,
       !searchFieldBlocksWindowHints(), !ContextMenuEvents.isMenuOpen,
       Preferences.windowHintsEnabled, TilesView.windowHintMode {
        if TilesView.handleWindowHintKeyDown(event, isARepeat) {
            return true
        }
    }
    if let event, shouldAbsorbSearchEditingKeyDown(event) {
        switch TilesView.handleSearchEditingKeyDown(event) {
        case .handled: return true
        case .passToField: return false
        case .passToShortcuts: break
        }
    }
    logKeyboardEvent(globalId, shortcutState, keyCode, modifiers, isARepeat)
    let someShortcutTriggered = triggerMatchingShortcuts(globalId, shortcutState, keyCode, modifiers, isARepeat)
    return someShortcutTriggered
}

private func logKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool) {
    if let globalId, let shortcutState {
        Logger.debug {
            let shortcut = KeyboardEventsTestable.globalShortcutsIds.first { $0.value == globalId }
            return "globalShortcut:\(shortcut?.key ?? "") state:\(shortcutState)"
        }
        return
    }
    // TODO: use proper pattern from SwiftBeaver to not compute SymbolicModifierFlagsTransformer when logs are off
    Logger.debug {
        let modifiersAsString = modifiers.flatMap { SymbolicModifierFlagsTransformer.shared.transformedValue(NSNumber(value: $0.rawValue)) }
        let keyCodeAsString = keyCode.flatMap { SymbolicKeyCodeTransformer.shared.transformedValue(NSNumber(value: $0)) }
        return "keys:\(modifiersAsString ?? "")\(keyCodeAsString ?? "") isARepeat:\(isARepeat)"
    }
}

private func searchFieldBlocksWindowHints() -> Bool {
    TilesView.isSearchEditing && !TilesView.searchFieldYieldsToHints
}

private func matchesActivePanelShortcut(_ event: NSEvent, _ shortcutId: String) -> Bool {
    guard let shortcut = ControlsTab.shortcuts[shortcutId]?.shortcut else { return false }
    if shortcut.keyCode == .none || shortcut.carbonKeyCode != UInt32(event.keyCode) { return false }
    let holdModifiers = ControlsTab.shortcuts[Preferences.indexToName("holdShortcut", App.shortcutIndex)]?.shortcut.carbonModifierFlags.cleaned() ?? 0
    let eventModifiers = cocoaToCarbonFlags(event.modifierFlags).cleaned()
    let shortcutModifiers = shortcut.carbonModifierFlags.cleaned()
    return eventModifiers == shortcutModifiers || eventModifiers == (shortcutModifiers | holdModifiers)
}

private func shouldAbsorbSearchEditingKeyDown(_ event: NSEvent?) -> Bool {
    guard let event, event.type == .keyDown, App.appIsBeingUsed, TilesPanel.shared.isKeyWindow, TilesView.isSearchEditing else {
        return false
    }
    return true
}

private func triggerMatchingShortcuts(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool) -> Bool {
    var someShortcutTriggered = false
    for shortcut in ControlsTab.shortcuts.values {
        if shortcut.matches(globalId, shortcutState, keyCode, modifiers) && shortcut.shouldTrigger() {
            shortcut.executeAction(isARepeat)
            // we want to pass-through alt-up to the active app, since it saw alt-down previously
            if !shortcut.id.starts(with: "holdShortcut") {
                someShortcutTriggered = true
            }
        }
        shortcut.redundantSafetyMeasures()
    }
    // TODO if we manage to move all keyboard listening to the background thread, we'll have issues returning this boolean
    // this function uses many objects that are also used on the main-thread. It also executes the actions
    // we'll have to rework this whole approach. Today we rely on somewhat in-order events/actions
    // special attention should be given to App.appIsBeingUsed which is being set to true when executing the nextWindowShortcut action
    return someShortcutTriggered
}
