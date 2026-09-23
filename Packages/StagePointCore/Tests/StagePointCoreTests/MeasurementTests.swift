import XCTest
@testable import StagePointCore

final class MeasurementTests: XCTestCase {
    private func sample(_ id: UUID, calculated: Point2D) throws -> StageMeasurement {
        try .init(calibrationID: id, stageSize: .init(width: 6, depth: 4), quad: .manual,
                  actualMeters: .init(x: 2, y: 3), calculatedMeters: calculated, isDemo: true, deviceDescription: "test")
    }
    func testKnownTenCentimeterErrorAndCalibrationIsolation() throws {
        let first = UUID(), second = UUID()
        let a = try sample(first, calculated: .init(x: 2.08, y: 2.94))
        let b = try sample(second, calculated: .init(x: 4, y: 3))
        XCTAssertEqual(a.errorMeters, 0.1, accuracy: 1e-9)
        let summary = MeasurementSummary(measurements: [a, b], calibrationID: first)!
        XCTAssertEqual(summary.count, 1)
        XCTAssertEqual(summary.meanCentimeters, 10, accuracy: 1e-9)
        XCTAssertNil(MeasurementSummary(measurements: [a, b], calibrationID: UUID()))
    }
    func testInvalidMeasurementCannotBeSaved() {
        XCTAssertThrowsError(try sample(UUID(), calculated: .init(x: -1, y: 2)))
        XCTAssertThrowsError(try sample(UUID(), calculated: .init(x: .nan, y: 2)))
    }
    func testReportRoundTripPreservesEvidence() throws {
        let record = try sample(UUID(), calculated: .init(x: 2, y: 3))
        let restored = try JSONDecoder().decode(StageMeasurement.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(restored, record)
        XCTAssertTrue(restored.isDemo)
    }
}
