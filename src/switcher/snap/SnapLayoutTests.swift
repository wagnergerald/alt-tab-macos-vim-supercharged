import XCTest

final class SnapLayoutTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 50, width: 1200, height: 800)
    private let mainMaxY: CGFloat = 1000

    private func rect(_ layout: SnapLayout) -> CGRect {
        SnapLayout.quartzRect(horizontal: layout.horizontalFractions, visibleFrameAppKit: visible,
                              mainScreenFrameMaxY: mainMaxY)
    }

    func testLeftHalfUsesFirstHalfOfVisibleWidth() {
        let r = rect(.leftHalf)
        XCTAssertEqual(r.origin.x, 100)
        XCTAssertEqual(r.width, 600)
        XCTAssertEqual(r.height, 800)
    }

    func testRightHalfStartsAtMidpoint() {
        let r = rect(.rightHalf)
        XCTAssertEqual(r.origin.x, 700)
        XCTAssertEqual(r.width, 600)
    }

    func testCenterHalfStartsAtQuarter() {
        let r = rect(.centerHalf)
        XCTAssertEqual(r.origin.x, 400)
        XCTAssertEqual(r.width, 600)
    }

    func testThirdsPartitionVisibleWidth() {
        let left = rect(.leftThird)
        let center = rect(.centerThird)
        let right = rect(.rightThird)
        XCTAssertEqual(left.origin.x, 100)
        XCTAssertEqual(left.width, 400, accuracy: 0.001)
        XCTAssertEqual(center.origin.x, 500, accuracy: 0.001)
        XCTAssertEqual(center.width, 400, accuracy: 0.001)
        XCTAssertEqual(right.origin.x, 900, accuracy: 0.001)
        XCTAssertEqual(right.width, 400, accuracy: 0.001)
        XCTAssertEqual(left.maxX, center.minX, accuracy: 0.001)
        XCTAssertEqual(center.maxX, right.minX, accuracy: 0.001)
    }

    func testCenterTwoThirdsIsCentered() {
        let r = rect(.centerTwoThirds)
        XCTAssertEqual(r.origin.x, 300, accuracy: 0.001)
        XCTAssertEqual(r.width, 800, accuracy: 0.001)
    }

    func testQuartzYFlipsFromAppKitVisibleFrame() {
        let r = rect(.leftHalf)
        // AppKit visible top is minY + height = 850; Quartz y = 1000 - 850 = 150
        XCTAssertEqual(r.origin.y, 150)
        XCTAssertEqual(r.height, 800)
    }

    func testPreferenceKeysAreUniqueAndStable() {
        let keys = SnapLayout.allCases.map(\.preferenceKey)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(SnapLayout.leftHalf.preferenceKey, "snapLayoutLeftHalfShortcut")
        XCTAssertEqual(SnapLayout.centerTwoThirds.preferenceKey, "snapLayoutCenterTwoThirdsShortcut")
    }

    func testDefaultKeyEquivalentsAreVimKeys() {
        // Case order is enum declaration order; centerTwoThirds uses j (main vim set) before the u/i/o thirds.
        XCTAssertEqual(SnapLayout.leftHalf.defaultKeyEquivalent, "h")
        XCTAssertEqual(SnapLayout.rightHalf.defaultKeyEquivalent, "l")
        XCTAssertEqual(SnapLayout.centerHalf.defaultKeyEquivalent, "k")
        XCTAssertEqual(SnapLayout.centerTwoThirds.defaultKeyEquivalent, "j")
        XCTAssertEqual(SnapLayout.leftThird.defaultKeyEquivalent, "u")
        XCTAssertEqual(SnapLayout.centerThird.defaultKeyEquivalent, "i")
        XCTAssertEqual(SnapLayout.rightThird.defaultKeyEquivalent, "o")
    }

    func testLayoutForPreferenceKeyRoundTrips() {
        for layout in SnapLayout.allCases {
            XCTAssertEqual(SnapLayout.layout(forPreferenceKey: layout.preferenceKey), layout)
        }
        XCTAssertNil(SnapLayout.layout(forPreferenceKey: "focusWindowShortcut"))
    }
}
