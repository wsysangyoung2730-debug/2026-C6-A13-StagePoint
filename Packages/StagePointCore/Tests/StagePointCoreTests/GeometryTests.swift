import XCTest
@testable import StagePointCore

final class GeometryTests: XCTestCase {
    func testStageRatioPreservesRelativePosition() {
        let reference = StageSize(width: 6, depth: 4)
        let ratio = reference.normalized(from: .init(x: 2, y: 3))!
        let actual = StageSize(width: 9, depth: 8).meters(from: ratio)
        XCTAssertEqual(actual.x, 3, accuracy: 1e-10)
        XCTAssertEqual(actual.y, 6, accuracy: 1e-10)
    }

    func testRejectsInvalidDimensions() {
        XCTAssertNil(StageSize(width: 0, depth: 4).normalized(from: .init(x: 1, y: 1)))
        XCTAssertFalse(StageSize(width: .infinity, depth: 4).isValid)
    }
}
