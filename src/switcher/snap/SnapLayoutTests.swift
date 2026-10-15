import XCTest

final class SnapLayoutTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 50, width: 1200, height: 800)
    private let mainMaxY: CGFloat = 1000

    private func rect(_ layout: SnapLayout, _ step: SnapSizeStep) -> CGRect {
        SnapLayout.quartzRect(placement: layout.placement(sizeStep: step),
                              visibleFrameAppKit: visible, mainScreenFrameMaxY: mainMaxY)
    }

    func testLeftHalfUsesFirstHalfOfVisibleWidth() {
        let r = rect(.leftHalf, .half)
        XCTAssertEqual(r.origin.x, 100)
        XCTAssertEqual(r.width, 600)
        XCTAssertEqual(r.height, 800)
    }

    func testRightHalfStartsAtMidpoint() {
        let r = rect(.rightHalf, .half)
        XCTAssertEqual(r.origin.x, 700)
        XCTAssertEqual(r.width, 600)
    }

    func testLargerRightHalfIsTwoThirds() {
        let r = rect(.rightHalf, .twoThirds)
        XCTAssertEqual(r.width, 800, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, 500, accuracy: 0.001)
    }

    func testSmallerLeftHalfIsOneThird() {
        let r = rect(.leftHalf, .third)
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, 100)
    }

    func testCenterHalfStartsAtQuarter() {
        let r = rect(.centerHalf, .half)
        XCTAssertEqual(r.origin.x, 400)
        XCTAssertEqual(r.width, 600)
    }

    func testThirdsPartitionVisibleWidth() {
        let left = rect(.leftThird, .third)
        let center = rect(.centerThird, .third)
        let right = rect(.rightThird, .third)
        XCTAssertEqual(left.maxX, center.minX, accuracy: 0.001)
        XCTAssertEqual(center.maxX, right.minX, accuracy: 0.001)
    }

    func testCenterTwoThirdsIsCentered() {
        let r = rect(.centerTwoThirds, .twoThirds)
        XCTAssertEqual(r.origin.x, 300, accuracy: 0.001)
        XCTAssertEqual(r.width, 800, accuracy: 0.001)
    }

    func testTopLeftQuarterUsesTopBand() {
        let r = rect(.topLeftQuarter, .half)
        XCTAssertEqual(r.width, 600)
        XCTAssertEqual(r.height, 400)
        // AppKit top band maxY = 50+800 = 850 → Quartz y = 1000-850 = 150
        XCTAssertEqual(r.origin.y, 150)
        XCTAssertEqual(r.origin.x, 100)
    }

    func testBottomRightQuarterUsesBottomBand() {
        let r = rect(.bottomRightQuarter, .half)
        XCTAssertEqual(r.origin.x, 700)
        // AppKit bottom band maxY = 50+400 = 450 → Quartz y = 1000-450 = 550
        XCTAssertEqual(r.origin.y, 550)
        XCTAssertEqual(r.height, 400)
    }

    func testQuartzYFlipsFromAppKitVisibleFrame() {
        let r = rect(.leftHalf, .half)
        XCTAssertEqual(r.origin.y, 150)
        XCTAssertEqual(r.height, 800)
    }

    func testSizeStepDigitsMapToFractions() {
        XCTAssertEqual(SnapSizeStep.fromDigit(1), .half)
        XCTAssertEqual(SnapSizeStep.fromDigit(2), .twoThirds)
        XCTAssertEqual(SnapSizeStep.fromDigit(3), .third)
        XCTAssertEqual(SnapSizeStep.half.widthFraction, 0.5)
        XCTAssertEqual(SnapSizeStep.twoThirds.widthFraction, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(SnapSizeStep.third.widthFraction, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testDefaultKeyEquivalentsIncludeQuarters() {
        XCTAssertEqual(SnapLayout.leftHalf.defaultKeyEquivalent, "h")
        XCTAssertEqual(SnapLayout.rightHalf.defaultKeyEquivalent, "l")
        XCTAssertEqual(SnapLayout.topLeftQuarter.defaultKeyEquivalent, "y")
        XCTAssertEqual(SnapLayout.topRightQuarter.defaultKeyEquivalent, "p")
        XCTAssertEqual(SnapLayout.bottomLeftQuarter.defaultKeyEquivalent, "n")
        XCTAssertEqual(SnapLayout.bottomRightQuarter.defaultKeyEquivalent, "m")
    }

    func testPreferenceKeysAreUniqueAndStable() {
        let keys = SnapLayout.allCases.map(\.preferenceKey)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(SnapLayout.allCases.count, 11)
    }

    func testLayoutForPreferenceKeyRoundTrips() {
        for layout in SnapLayout.allCases {
            XCTAssertEqual(SnapLayout.layout(forPreferenceKey: layout.preferenceKey), layout)
        }
        XCTAssertNil(SnapLayout.layout(forPreferenceKey: "focusWindowShortcut"))
    }
}
