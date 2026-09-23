import Foundation

public struct StageMeasurement: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let calibrationID: UUID
    public let stageSize: StageSize
    public let quad: StageQuad
    public let actualMeters: Point2D
    public let calculatedMeters: Point2D
    public let isDemo: Bool
    public let deviceDescription: String

    public init(calibrationID: UUID, stageSize: StageSize, quad: StageQuad,
                actualMeters: Point2D, calculatedMeters: Point2D, isDemo: Bool, deviceDescription: String) throws {
        guard stageSize.isValid, quad.isValid,
              stageSize.normalized(from: actualMeters)?.isUnitPoint == true,
              stageSize.normalized(from: calculatedMeters)?.isUnitPoint == true else {
            throw TemplateError.invalid("검증 좌표와 무대 크기·기준점을 확인하세요.")
        }
        id = UUID(); date = Date(); self.calibrationID = calibrationID
        self.stageSize = stageSize; self.quad = quad; self.actualMeters = actualMeters
        self.calculatedMeters = calculatedMeters; self.isDemo = isDemo; self.deviceDescription = deviceDescription
    }
    public var errorMeters: Double { actualMeters.distance(to: calculatedMeters) }
}

public struct MeasurementSummary {
    public let count: Int
    public let meanCentimeters: Double
    public let maximumCentimeters: Double
    public init?(measurements: [StageMeasurement], calibrationID: UUID) {
        let errors = measurements.filter { $0.calibrationID == calibrationID }.map { $0.errorMeters * 100 }
        guard !errors.isEmpty else { return nil }
        count = errors.count; meanCentimeters = errors.reduce(0, +) / Double(count)
        maximumCentimeters = errors.max()!
    }
}
