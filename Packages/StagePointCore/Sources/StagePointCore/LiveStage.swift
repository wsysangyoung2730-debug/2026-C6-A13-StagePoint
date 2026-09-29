import Foundation

public enum DeviceRole: String, Codable, CaseIterable, Sendable {
    case camera, monitor
    public var title: String { self == .camera ? "촬영 기기 · iPhone" : "운영 기기 · iPad" }
}

/// Confirmed rectangular performance area, not the whole RoomPlan room or a safety guarantee.
public struct LiveStage: Codable, Equatable, Sendable {
    public var id: UUID
    public var revision: Int
    public var size: StageSize
    public var source: String
    public var confirmed: Bool
    public init(size: StageSize, source: String = "수동", confirmed: Bool = false) {
        id = UUID(); revision = 1; self.size = size; self.source = source; self.confirmed = confirmed
    }
    public var isValid: Bool {
        revision > 0 && size.isValid && size.width <= 100 && size.depth <= 100 && source.count <= 100
    }
}

public struct LiveCalibration: Codable, Equatable, Sendable {
    public var id: UUID
    public var stageID: UUID
    public var stageRevision: Int
    public var quad: StageQuad
    public var validated: Bool
    public init(stage: LiveStage, quad: StageQuad) {
        id = UUID(); stageID = stage.id; stageRevision = stage.revision
        self.quad = quad; validated = false
    }
    public func matches(_ stage: LiveStage) -> Bool {
        stageID == stage.id && stageRevision == stage.revision && quad.isValid && stage.confirmed
    }
}

/// Full snapshots make reconnect recovery independent of missed intermediate updates.
public struct LiveSnapshot: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var revision: Int
    public var phase: String
    public var stage: LiveStage?
    public var calibration: LiveCalibration?
    public var target: Point2D?
    public init(sessionID: UUID = UUID()) {
        self.sessionID = sessionID; revision = 0; phase = "연결 대기"
    }
    public var canProject: Bool {
        guard let stage, let calibration else { return false }
        return stage.isValid && calibration.matches(stage) && calibration.validated
    }
    public func validate() -> Bool {
        guard revision >= 0, phase.count <= 100, target?.isUnitPoint ?? true else { return false }
        if let stage, !stage.isValid { return false }
        if let calibration {
            guard let stage, calibration.matches(stage) else { return false }
        }
        return true
    }
}

public struct LiveCommand: Codable, Sendable {
    public var id: UUID
    public var sessionID: UUID
    public var calibrationID: UUID
    public var target: Point2D
    public init(sessionID: UUID, calibrationID: UUID, target: Point2D) {
        id = UUID(); self.sessionID = sessionID; self.calibrationID = calibrationID; self.target = target
    }
}

public struct LivePacket: Codable, Sendable {
    public var version = 1
    public var snapshot: LiveSnapshot?
    public var command: LiveCommand?
    public var acknowledgedID: UUID?
    public var error: String?
    public init(snapshot: LiveSnapshot? = nil, command: LiveCommand? = nil, acknowledgedID: UUID? = nil, error: String? = nil) {
        self.snapshot = snapshot; self.command = command; self.acknowledgedID = acknowledgedID; self.error = error
    }
    public func encoded() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 64_000 else { throw TemplateError.invalid("메시지가 너무 큽니다.") }
        let packet = try JSONDecoder().decode(Self.self, from: data)
        guard packet.version == 1, packet.snapshot?.validate() ?? true,
              packet.command?.target.isUnitPoint ?? true else { throw TemplateError.invalid("유효하지 않은 메시지입니다.") }
        return packet
    }
}

public struct SnapshotReceiver {
    public private(set) var value: LiveSnapshot?
    public init() {}
    public mutating func reset() { value = nil }
    public mutating func accept(_ next: LiveSnapshot) -> Bool {
        guard next.validate() else { return false }
        if let value {
            guard value.sessionID == next.sessionID, next.revision > value.revision else { return false }
        }
        value = next; return true
    }
}
