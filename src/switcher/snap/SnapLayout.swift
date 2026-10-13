import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

/// Fixed Rectangle-style snap presets. Fractions are of the screen's AppKit `visibleFrame`; the returned
/// `CGRect` is in Quartz top-left space (same as AX `kAXPosition` / `kAXSize` and `Window.position`).
enum SnapLayout: String, CaseIterable {
    case leftHalf
    case rightHalf
    case centerHalf
    case leftThird
    case centerThird
    case rightThird
    case centerTwoThirds

    var preferenceKey: String {
        switch self {
        case .leftHalf: return "snapLayoutLeftHalfShortcut"
        case .rightHalf: return "snapLayoutRightHalfShortcut"
        case .centerHalf: return "snapLayoutCenterHalfShortcut"
        case .leftThird: return "snapLayoutLeftThirdShortcut"
        case .centerThird: return "snapLayoutCenterThirdShortcut"
        case .rightThird: return "snapLayoutRightThirdShortcut"
        case .centerTwoThirds: return "snapLayoutCenterTwoThirdsShortcut"
        }
    }

    /// Vim-style defaults. `h`/`l`/`k`/`j` are the main motions; `u`/`i`/`o` cover the thirds row.
    /// Uppercase (Shift+letter) matches too while the snap panel is open — see `layoutMatching(event:)`.
    var defaultKeyEquivalent: String {
        switch self {
        case .leftHalf: return "h"
        case .rightHalf: return "l"
        case .centerHalf: return "k"
        case .centerTwoThirds: return "j"
        case .leftThird: return "u"
        case .centerThird: return "i"
        case .rightThird: return "o"
        }
    }

    var localizedTitle: String {
        switch self {
        case .leftHalf: return NSLocalizedString("snapLayout.leftHalf", comment: "")
        case .rightHalf: return NSLocalizedString("snapLayout.rightHalf", comment: "")
        case .centerHalf: return NSLocalizedString("snapLayout.centerHalf", comment: "")
        case .leftThird: return NSLocalizedString("snapLayout.leftThird", comment: "")
        case .centerThird: return NSLocalizedString("snapLayout.centerThird", comment: "")
        case .rightThird: return NSLocalizedString("snapLayout.rightThird", comment: "")
        case .centerTwoThirds: return NSLocalizedString("snapLayout.centerTwoThirds", comment: "")
        }
    }

    /// Horizontal placement as (originX, width) fractions of the visible frame. Height is always full.
    var horizontalFractions: (x: CGFloat, w: CGFloat) {
        switch self {
        case .leftHalf: return (0, 0.5)
        case .rightHalf: return (0.5, 0.5)
        case .centerHalf: return (0.25, 0.5)
        case .leftThird: return (0, 1.0 / 3.0)
        case .centerThird: return (1.0 / 3.0, 1.0 / 3.0)
        case .rightThird: return (2.0 / 3.0, 1.0 / 3.0)
        case .centerTwoThirds: return (1.0 / 6.0, 2.0 / 3.0)
        }
    }

    /// AppKit `visibleFrame` (bottom-left origin) → Quartz top-left frame for AX writes.
    static func quartzRect(horizontal: (x: CGFloat, w: CGFloat), visibleFrameAppKit: CGRect,
                           mainScreenFrameMaxY: CGFloat) -> CGRect {
        let appKit = CGRect(
            x: visibleFrameAppKit.minX + visibleFrameAppKit.width * horizontal.x,
            y: visibleFrameAppKit.minY,
            width: visibleFrameAppKit.width * horizontal.w,
            height: visibleFrameAppKit.height)
        return CGRect(
            x: appKit.minX,
            y: mainScreenFrameMaxY - appKit.maxY,
            width: appKit.width,
            height: appKit.height)
    }

    func quartzRect(on screen: NSScreen) -> CGRect {
        let mainMaxY = NSMaxY(NSScreen.screens[0].frame)
        return Self.quartzRect(horizontal: horizontalFractions, visibleFrameAppKit: screen.visibleFrame,
                               mainScreenFrameMaxY: mainMaxY)
    }

    static func layout(forPreferenceKey key: String) -> SnapLayout? {
        allCases.first { $0.preferenceKey == key }
    }

    static var allPreferenceKeys: [String] {
        allCases.map(\.preferenceKey)
    }

    /// Match a keyDown to a snap layout. Shift is ignored so `h` and `H` both select left half when the
    /// binding is the letter without modifiers (vim navigation reuses the same letters outside snap mode).
    static func layoutMatching(event: NSEvent) -> SnapLayout? {
        let eventKey = UInt32(event.keyCode)
        let eventMods = cocoaToCarbonFlags(event.modifierFlags).cleaned()
        let holdMods = ControlsTab.shortcuts[Preferences.indexToName("holdShortcut", SwitcherSession.activeShortcutIndex)]?
            .shortcut.carbonModifierFlags.cleaned() ?? 0
        let shiftBit = UInt32(shiftKey)
        for layout in allCases {
            guard let shortcut = ControlsTab.shortcuts[layout.preferenceKey]?.shortcut,
                  shortcut.keyCode != .none,
                  shortcut.carbonKeyCode == eventKey else { continue }
            let shortcutMods = shortcut.carbonModifierFlags.cleaned()
            let eventSansShift = eventMods & ~shiftBit
            let shortcutSansShift = shortcutMods & ~shiftBit
            if eventSansShift == shortcutSansShift || eventSansShift == (shortcutSansShift | holdMods) {
                return layout
            }
        }
        return nil
    }
}
