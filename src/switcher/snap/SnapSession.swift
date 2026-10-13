import Cocoa

/// Post-confirm snap mode: the switcher stays open with a locked window until a layout key, Space/Escape
/// (focus without resize), or cancel (dismiss without focus).
enum SnapSession {
    private(set) static var lockedWindow: Window?
    static var isActive: Bool { lockedWindow != nil }

    static func begin(locking window: Window) {
        lockedWindow = window
    }

    static func clear() {
        lockedWindow = nil
    }
}
