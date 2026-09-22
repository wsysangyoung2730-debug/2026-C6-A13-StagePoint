import XCTest
@testable import StagePointCore

final class HomographyTests: XCTestCase {
    func testKnownPerspectiveAndInverseAtIndependentPoints() {
        func expected(_ p: Point2D) -> Point2D {
            .init(x: (0.6 * p.x + 0.2 * p.y + 0.1) / (0.4 * p.y + 1),
                  y: (-0.5 * p.y + 0.8) / (0.4 * p.y + 1))
        }
        let unit: [Point2D] = [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]
        let map = StageMapping(quad: .init(corners: unit.map(expected)))!
        for p in [Point2D(x: 0.2, y: 0.7), .init(x: 0.8, y: 0.1), .init(x: 0.5, y: 0.5)] {
            let projected = map.imagePoint(from: p)!
            XCTAssertEqual(projected.x, expected(p).x, accuracy: 1e-9)
            XCTAssertEqual(projected.y, expected(p).y, accuracy: 1e-9)
            let restored = map.stagePoint(from: expected(p))!
            XCTAssertEqual(restored.x, p.x, accuracy: 1e-9)
            XCTAssertEqual(restored.y, p.y, accuracy: 1e-9)
        }
    }
    func testRejectsCrossedCollinearAndNonFiniteQuads() {
        let a = Point2D(x: 0, y: 0), b = Point2D(x: 1, y: 1)
        XCTAssertNil(StageMapping(quad: .init(corners: [a, b, .init(x: 0, y: 1), .init(x: 1, y: 0)])))
        XCTAssertNil(StageMapping(quad: .init(corners: [a, a, b, b])))
        XCTAssertNil(StageMapping(quad: .init(corners: [a, b, .init(x: .nan, y: 0), a])))
    }
    func testOriginCanFaceOppositeCamera() {
        var quad = StageQuad.manual
        quad.corners = Array(quad.corners[2...]) + Array(quad.corners[0..<2])
        let map = StageMapping(quad: quad)!
        XCTAssertEqual(map.imagePoint(from: .init(x: 0, y: 0))!.x, quad.corners[0].x, accuracy: 1e-9)
    }
}
