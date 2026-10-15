import Cocoa

/// Post-confirm snap mode: the switcher stays open with a locked window until a layout key (resize
/// then focus), Space (focus without resize), or Escape (step back: clear pending digit, else leave
/// snap and restore the prior window-selection / hint mode). Digits `1`–`3` only set a pending size
/// and keep the panel open for the next layout key.
enum SnapSession {
    private(set) static var lockedWindow: Window?
    static var isActive: Bool { lockedWindow != nil }

    /// Digit `1`–`3` typed before a layout key. Consumed by the next layout apply.
    static var pendingSizeStep: SnapSizeStep?

    static func begin(locking window: Window) {
        lockedWindow = window
        pendingSizeStep = nil
    }

    static func clear() {
        lockedWindow = nil
        pendingSizeStep = nil
    }

    /// Explicit digit, else the layout's default size.
    static func resolveSizeStep(for layout: SnapLayout) -> SnapSizeStep {
        if let pending = pendingSizeStep {
            pendingSizeStep = nil
            return pending
        }
        return layout.defaultSizeStep
    }
}
