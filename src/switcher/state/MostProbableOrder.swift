import Foundation

/// Reuse-probability ranking for the switcher's "Most Probable" window order.
///
/// Pure kernel: scores and compares from a snapshot of app→app transition weights. Persistence and
/// recording live in `AppTransitionStats`. v1 is **app-affinity only** (bundle ID); title keys are
/// deferred so Chrome-like title churn cannot pollute the table.
enum MostProbableOrder {
    static let defaultPinCount = 3
    /// Half-life for edge weights (~36 hours): yesterday's habits still matter; last month's fade.
    static let halfLife: TimeInterval = 1.5 * 24 * 3600

    /// P(next app = `toBundle` | just left `fromBundle`), from decayed transition weights.
    static func appScore(toBundle: String?, fromBundle: String?,
                         weights: [String: [String: Double]]) -> Double {
        guard let to = toBundle, !to.isEmpty,
              let from = fromBundle, !from.isEmpty,
              let row = weights[from], !row.isEmpty else { return 0 }
        let total = row.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return (row[to] ?? 0) / total
    }

    static func decayedWeight(_ weight: Double, age: TimeInterval,
                              halfLife: TimeInterval = halfLife) -> Double {
        guard weight > 0, halfLife > 0 else { return 0 }
        return weight * pow(0.5, max(0, age) / halfLife)
    }

    /// Bump `from → to`. Same-app / empty ids are ignored (Chrome window churn stays out).
    static func record(weights: inout [String: [String: Double]], from: String, to: String,
                       amount: Double = 1) {
        guard amount > 0, from != to, !from.isEmpty, !to.isEmpty else { return }
        weights[from, default: [:]][to, default: 0] += amount
    }

    /// Apply age decay to every edge; drop dust so the table stays small.
    static func decayAll(_ weights: inout [String: [String: Double]], age: TimeInterval,
                         halfLife: TimeInterval = halfLife, dropBelow: Double = 0.01) {
        guard age > 0 else { return }
        for from in Array(weights.keys) {
            guard var row = weights[from] else { continue }
            for to in Array(row.keys) {
                let next = decayedWeight(row[to] ?? 0, age: age, halfLife: halfLife)
                if next <= dropBelow { row.removeValue(forKey: to) } else { row[to] = next }
            }
            if row.isEmpty { weights.removeValue(forKey: from) } else { weights[from] = row }
        }
    }
}
