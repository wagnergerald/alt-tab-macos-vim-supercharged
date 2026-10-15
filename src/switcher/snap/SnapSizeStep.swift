import Foundation

/// Width (and for quarters, height-band width) steps for a snap layout. Chosen with digit `1`/`2`/`3`
/// before a layout key (`1` = half, `2` = two-thirds / larger, `3` = one-third).
enum SnapSizeStep: Int, CaseIterable {
    case half = 1
    case twoThirds = 2
    case third = 3

    var widthFraction: CGFloat {
        switch self {
        case .half: return 0.5
        case .twoThirds: return 2.0 / 3.0
        case .third: return 1.0 / 3.0
        }
    }

    static func fromDigit(_ digit: Int) -> SnapSizeStep? {
        SnapSizeStep(rawValue: digit)
    }
}
