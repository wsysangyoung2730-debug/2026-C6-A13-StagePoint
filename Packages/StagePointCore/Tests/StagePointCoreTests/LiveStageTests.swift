import XCTest
@testable import StagePointCore

final class LiveStageTests: XCTestCase {
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
