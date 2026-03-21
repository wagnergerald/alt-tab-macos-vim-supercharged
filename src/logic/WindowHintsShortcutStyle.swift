import Foundation

enum WindowHintsShortcutStyle {
    private static let backupKey = "shortcutStyleBackedUpBeforeWindowHints"

    static func applyForWindowHintsPreferenceChange() {
        if Preferences.windowHintsEnabled {
            if UserDefaults.standard.object(forKey: backupKey) == nil {
                let current = Preferences.shortcutStyle
                if current != .doNothingOnRelease {
                    UserDefaults.standard.set(current.indexAsString, forKey: backupKey)
                }
            }
            if Preferences.shortcutStyle != .doNothingOnRelease {
                Preferences.set("shortcutStyle", ShortcutStylePreference.doNothingOnRelease.indexAsString)
            }
        } else if let backup = UserDefaults.standard.string(forKey: backupKey) {
            UserDefaults.standard.removeObject(forKey: backupKey)
            Preferences.set("shortcutStyle", backup)
        }
        CachedUserDefaults.removeFromCache("shortcutStyle")
    }

    static func enforceOnLaunchIfNeeded() {
        guard Preferences.windowHintsEnabled, Preferences.shortcutStyle != .doNothingOnRelease else { return }
        if UserDefaults.standard.object(forKey: backupKey) == nil {
            UserDefaults.standard.set(Preferences.shortcutStyle.indexAsString, forKey: backupKey)
        }
        Preferences.set("shortcutStyle", ShortcutStylePreference.doNothingOnRelease.indexAsString)
        CachedUserDefaults.removeFromCache("shortcutStyle")
    }
}
