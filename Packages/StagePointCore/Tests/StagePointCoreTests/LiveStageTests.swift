import XCTest
@testable import StagePointCore

final class LiveStageTests: XCTestCase {
    func testIndependentProbeAndPhysicalError() throws {
        let quad = StageQuad.manual
        let image = try XCTUnwrap(StageMapping(quad: quad)?.imagePoint(from: .init(x: 0.5, y: 0.5)))
        let sample = try XCTUnwrap(CalibrationProbe(imagePoint: image, measured: .init(x: 4.1, y: 3), quad: quad, size: .init(width: 8, depth: 6)))
        XCTAssertEqual(sample.errorMeters, 0.1, accuracy: 0.00001)
        XCTAssertNil(CalibrationProbe(imagePoint: quad.corners[0], measured: .init(x: 0, y: 0), quad: quad, size: .init(width: 8, depth: 6)))
        XCTAssertNil(CalibrationProbe(imagePoint: image, measured: .init(x: 9, y: 3), quad: quad, size: .init(width: 8, depth: 6)))
    }
    func testCalibrationRequiresConfirmationAndValidation() {
        var value = LiveSnapshot()
        value.stage = LiveStage(size: .init(width: 8, depth: 6), confirmed: true)
        value.calibration = LiveCalibration(stage: value.stage!, quad: .manual)
        XCTAssertFalse(value.canProject)
        value.calibration?.validated = true
        XCTAssertTrue(value.canProject)
        value.stage?.revision += 1
        XCTAssertFalse(value.canProject)
        XCTAssertFalse(value.validate())
    }
    func testReceiverRejectsStaleAndForeignSession() {
        var receiver = SnapshotReceiver()
        var snapshot = LiveSnapshot()
        XCTAssertTrue(receiver.accept(snapshot))
        XCTAssertFalse(receiver.accept(snapshot))
        snapshot.revision += 1
        XCTAssertTrue(receiver.accept(snapshot))
        XCTAssertFalse(receiver.accept(LiveSnapshot()))
        receiver.reset()
        XCTAssertTrue(receiver.accept(LiveSnapshot()))
    }
    func testWireRoundTripAndInvalidBounds() throws {
        var value = LiveSnapshot()
        value.stage = LiveStage(size: .init(width: 8, depth: 6))
        let data = try LivePacket(snapshot: value).encoded()
        XCTAssertEqual(try LivePacket.decode(data).snapshot, value)
        value.target = .init(x: 2, y: 0)
        XCTAssertThrowsError(try LivePacket.decode(LivePacket(snapshot: value).encoded()))
        XCTAssertThrowsError(try LivePacket.decode(Data(repeating: 0, count: 64_001)))
    }
}
