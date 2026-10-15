import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

/// Fixed Rectangle-style snap presets. Fractions are of the screen's AppKit `visibleFrame`; the returned
/// `CGRect` is in Quartz top-left space (same as AX `kAXPosition` / `kAXSize` and `Window.position`).
///
/// Width follows `SnapSizeStep` (half / two-thirds / third). Quarters use the top or bottom half of the
/// visible frame and the same width steps.
enum SnapLayout: String, CaseIterable {
    case leftHalf
    case rightHalf
    case centerHalf
    case leftThird
    case centerThird
    case rightThird
    case centerTwoThirds
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter

    var preferenceKey: String {
        switch self {
        case .leftHalf: return "snapLayoutLeftHalfShortcut"
        case .rightHalf: return "snapLayoutRightHalfShortcut"
        case .centerHalf: return "snapLayoutCenterHalfShortcut"
        case .leftThird: return "snapLayoutLeftThirdShortcut"
        case .centerThird: return "snapLayoutCenterThirdShortcut"
        case .rightThird: return "snapLayoutRightThirdShortcut"
        case .centerTwoThirds: return "snapLayoutCenterTwoThirdsShortcut"
        case .topLeftQuarter: return "snapLayoutTopLeftQuarterShortcut"
        case .topRightQuarter: return "snapLayoutTopRightQuarterShortcut"
        case .bottomLeftQuarter: return "snapLayoutBottomLeftQuarterShortcut"
        case .bottomRightQuarter: return "snapLayoutBottomRightQuarterShortcut"
        }
    }

    /// Vim-style defaults. Quarters sit on `y`/`p`/`n`/`m`. Uppercase matches too — see `layoutMatching`.
    var defaultKeyEquivalent: String {
        switch self {
        case .leftHalf: return "h"
        case .rightHalf: return "l"
        case .centerHalf: return "k"
        case .centerTwoThirds: return "j"
        case .leftThird: return "u"
        case .centerThird: return "i"
        case .rightThird: return "o"
        case .topLeftQuarter: return "y"
        case .topRightQuarter: return "p"
        case .bottomLeftQuarter: return "n"
        case .bottomRightQuarter: return "m"
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
        case .topLeftQuarter: return NSLocalizedString("snapLayout.topLeftQuarter", comment: "")
        case .topRightQuarter: return NSLocalizedString("snapLayout.topRightQuarter", comment: "")
        case .bottomLeftQuarter: return NSLocalizedString("snapLayout.bottomLeftQuarter", comment: "")
        case .bottomRightQuarter: return NSLocalizedString("snapLayout.bottomRightQuarter", comment: "")
        }
    }

    /// First press (no digit, no prior same-key cycle) lands on this step.
    var defaultSizeStep: SnapSizeStep {
        switch self {
        case .leftHalf, .rightHalf, .centerHalf,
             .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            return .half
        case .leftThird, .centerThird, .rightThird:
            return .third
        case .centerTwoThirds:
            return .twoThirds
        }
    }

    /// Horizontal + vertical placement as fractions of the visible frame. `y` is from the AppKit bottom.
    func placement(sizeStep: SnapSizeStep) -> (x: CGFloat, w: CGFloat, y: CGFloat, h: CGFloat) {
        let w = sizeStep.widthFraction
        let x: CGFloat
        switch self {
        case .leftHalf, .leftThird, .topLeftQuarter, .bottomLeftQuarter:
            x = 0
        case .rightHalf, .rightThird, .topRightQuarter, .bottomRightQuarter:
            x = 1 - w
        case .centerHalf, .centerThird, .centerTwoThirds:
            x = (1 - w) / 2
        }
        switch self {
        case .topLeftQuarter, .topRightQuarter:
            return (x, w, 0.5, 0.5)
        case .bottomLeftQuarter, .bottomRightQuarter:
            return (x, w, 0, 0.5)
        default:
            return (x, w, 0, 1)
        }
    }

    /// Glyph fractions at the layout's default size (panel / prefs preview).
    var glyphFractions: (x: CGFloat, w: CGFloat, y: CGFloat, h: CGFloat) {
        placement(sizeStep: defaultSizeStep)
    }

    /// AppKit `visibleFrame` (bottom-left origin) → Quartz top-left frame for AX writes.
    static func quartzRect(placement: (x: CGFloat, w: CGFloat, y: CGFloat, h: CGFloat),
                           visibleFrameAppKit: CGRect, mainScreenFrameMaxY: CGFloat) -> CGRect {
        let appKit = CGRect(
            x: visibleFrameAppKit.minX + visibleFrameAppKit.width * placement.x,
            y: visibleFrameAppKit.minY + visibleFrameAppKit.height * placement.y,
            width: visibleFrameAppKit.width * placement.w,
            height: visibleFrameAppKit.height * placement.h)
        return CGRect(
            x: appKit.minX,
            y: mainScreenFrameMaxY - appKit.maxY,
            width: appKit.width,
            height: appKit.height)
    }

    func quartzRect(on screen: NSScreen, sizeStep: SnapSizeStep) -> CGRect {
        let mainMaxY = NSMaxY(NSScreen.screens[0].frame)
        return Self.quartzRect(placement: placement(sizeStep: sizeStep),
                               visibleFrameAppKit: screen.visibleFrame,
                               mainScreenFrameMaxY: mainMaxY)
    }

    static func layout(forPreferenceKey key: String) -> SnapLayout? {
        allCases.first { $0.preferenceKey == key }
    }

    static var allPreferenceKeys: [String] {
        allCases.map(\.preferenceKey)
    }

    /// Match a keyDown to a snap layout. Shift is ignored so `h` and `H` both select left half.
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

    /// Digits `1`–`3` (no modifiers other than optional Shift) set the size step before a layout key.
    static func sizeDigit(from event: NSEvent) -> Int? {
        let blocked = event.modifierFlags.intersection([.option, .command, .control])
        guard blocked.isEmpty else { return nil }
        switch Int(event.keyCode) {
        case kVK_ANSI_1: return 1
        case kVK_ANSI_2: return 2
        case kVK_ANSI_3: return 3
        default: return nil
        }
    }
}
