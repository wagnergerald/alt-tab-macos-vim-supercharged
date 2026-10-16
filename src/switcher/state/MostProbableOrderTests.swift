import XCTest

final class MostProbableOrderTests: XCTestCase {

    func testAppScoreIsConditionalProbability() {
        let weights = ["com.a": ["com.b": 3.0, "com.c": 1.0]]
        XCTAssertEqual(MostProbableOrder.appScore(toBundle: "com.b", fromBundle: "com.a",
                                                  weights: weights), 0.75, accuracy: 1e-9)
        XCTAssertEqual(MostProbableOrder.appScore(toBundle: "com.c", fromBundle: "com.a",
                                                  weights: weights), 0.25, accuracy: 1e-9)
    }

    func testAppScoreMissingEdgeIsZero() {
        XCTAssertEqual(MostProbableOrder.appScore(toBundle: "com.b", fromBundle: "com.a",
                                                  weights: [:]), 0)
        XCTAssertEqual(MostProbableOrder.appScore(toBundle: nil, fromBundle: "com.a",
                                                  weights: ["com.a": ["com.b": 1]]), 0)
        XCTAssertEqual(MostProbableOrder.appScore(toBundle: "com.b", fromBundle: nil,
                                                  weights: ["com.a": ["com.b": 1]]), 0)
    }

    func testRecordIgnoresSameAppAndEmpty() {
        var weights = [String: [String: Double]]()
        MostProbableOrder.record(weights: &weights, from: "com.a", to: "com.a")
        MostProbableOrder.record(weights: &weights, from: "", to: "com.b")
        MostProbableOrder.record(weights: &weights, from: "com.a", to: "")
        XCTAssertTrue(weights.isEmpty)
        MostProbableOrder.record(weights: &weights, from: "com.a", to: "com.b")
        MostProbableOrder.record(weights: &weights, from: "com.a", to: "com.b", amount: 2)
        XCTAssertEqual(weights["com.a"]?["com.b"], 3)
    }

    func testDecayHalvesWeightAtHalfLife() {
        let half = MostProbableOrder.halfLife
        XCTAssertEqual(MostProbableOrder.decayedWeight(8, age: half, halfLife: half), 4, accuracy: 1e-9)
        XCTAssertEqual(MostProbableOrder.decayedWeight(8, age: 2 * half, halfLife: half), 2, accuracy: 1e-9)
    }

    func testDecayAllDropsDust() {
        var weights = ["com.a": ["com.b": 0.02, "com.c": 1.0]]
        MostProbableOrder.decayAll(&weights, age: MostProbableOrder.halfLife, dropBelow: 0.01)
        XCTAssertNil(weights["com.a"]?["com.b"])
        XCTAssertEqual(weights["com.a"]?["com.c"] ?? 0, 0.5, accuracy: 1e-9)
    }
}
