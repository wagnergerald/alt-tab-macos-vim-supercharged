import Foundation

/// Local app→app focus-transition weights for `MostProbableOrder`. Same shape as `UsageStats`:
/// in-memory cache, debounced UserDefaults flush, prune/decay on a utility queue.
struct AppTransitionStats {
    private static let defaults = UserDefaults(suiteName: "\(App.bundleIdentifier).transitions")!
    private static let writeQueue = DispatchQueue(label: "AppTransitionStats.writeQueue", qos: .utility)
    private static let storageKey = "appTransitions"
    private static let lastDecayKey = "lastDecayAt"
    private static let flushDelay: TimeInterval = 2
    /// Skip recording while the switcher itself holds focus — those bumps are navigation, not work switches.
    private static var lastRecordedBundleId: String?

    private static var cache: [String: [String: Double]]?
    private static var dirty = false
    private static var flushScheduled = false

    /// Snapshot for sorting. Decayed since the last prune so scores match wall-clock age.
    static func weightSnapshot(now: TimeInterval = Date().timeIntervalSince1970) -> [String: [String: Double]] {
        writeQueue.sync {
            ensureLoadedOnQueue()
            var copy = cache!
            let last = defaults.double(forKey: lastDecayKey)
            if last > 0 { MostProbableOrder.decayAll(&copy, age: now - last) }
            return copy
        }
    }

    /// Record a user focus move between apps. Same bundle / empty / AltTab itself are ignored.
    static func recordFocusMove(toBundle: String?) {
        guard let to = toBundle, !to.isEmpty, to != App.bundleIdentifier else { return }
        let from = lastRecordedBundleId
        lastRecordedBundleId = to
        guard let from, from != to else { return }
        writeQueue.async {
            ensureLoadedOnQueue()
            MostProbableOrder.record(weights: &cache!, from: from, to: to)
            dirty = true
            scheduleFlushOnQueue()
        }
    }

    static func prune(now: TimeInterval = Date().timeIntervalSince1970) {
        writeQueue.async {
            ensureLoadedOnQueue()
            let last = defaults.double(forKey: lastDecayKey)
            let age = last > 0 ? now - last : 0
            if age > 0 {
                MostProbableOrder.decayAll(&cache!, age: age)
                dirty = true
            }
            defaults.set(now, forKey: lastDecayKey)
            flushOnQueue()
        }
    }

    static func flushNow() {
        writeQueue.sync { flushOnQueue() }
    }

    #if DEBUG
    /// Test seam: replace the in-memory table without touching UserDefaults.
    static func qaReplaceWeights(_ weights: [String: [String: Double]]) {
        writeQueue.sync {
            cache = weights
            dirty = false
        }
    }

    static func qaReset() {
        writeQueue.sync {
            cache = [:]
            dirty = false
            lastRecordedBundleId = nil
        }
    }
    #endif

    // MARK: - writeQueue-only

    private static func ensureLoadedOnQueue() {
        guard cache == nil else { return }
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            cache = decoded
        } else {
            cache = [:]
        }
    }

    private static func scheduleFlushOnQueue() {
        guard !flushScheduled else { return }
        flushScheduled = true
        writeQueue.asyncAfter(deadline: .now() + flushDelay) { flushOnQueue() }
    }

    private static func flushOnQueue() {
        flushScheduled = false
        guard dirty, let cache else { return }
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: storageKey)
        }
        dirty = false
    }
}
