import XCTest
@testable import StagePointCore

final class TemplateTests: XCTestCase {
    func testFileRoundTripPreservesRatioAndIdentity() throws {
        let original = StageTemplate.example
        let restored = try StageTemplate.decode(original.encoded())
        XCTAssertEqual(restored, original)
        let position = StageSize(width: 9, depth: 8).meters(from: restored.targets[0].normalized)
        XCTAssertEqual(position, Point2D(x: 3, y: 6))
    }
    func testRejectsOffStageDuplicateAndFutureVersion() throws {
        var template = StageTemplate.example
        template.targets[0].normalized.x = 1.1
        XCTAssertThrowsError(try template.encoded())
        template = .example; template.targets.append(template.targets[0])
        XCTAssertThrowsError(try template.validate())
        template = .example; template.version = 2
        XCTAssertThrowsError(try StageTemplate.decode(JSONEncoder().encode(template)))
    }
    func testRejectsInvalidJSONAndOversizedFiles() {
        XCTAssertThrowsError(try StageTemplate.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try StageTemplate.decode(Data(repeating: 0, count: 1_000_001)))
    }
    func testMappingImportedTargetUsesSameRatioAtDifferentSize() throws {
        let template = try StageTemplate.decode(StageTemplate.example.encoded())
        let map = StageMapping(quad: .manual)!
        let normalized = template.targets[0].normalized
        let image = map.imagePoint(from: normalized)!
        let readBack = map.stagePoint(from: image)!
        let actual = StageSize(width: 12, depth: 6).meters(from: readBack)
        XCTAssertEqual(actual.x, 4, accuracy: 1e-9)
        XCTAssertEqual(actual.y, 4.5, accuracy: 1e-9)
    }
}
