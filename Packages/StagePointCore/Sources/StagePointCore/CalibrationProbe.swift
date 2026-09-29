import Foundation

public struct CalibrationProbe: Codable, Equatable, Sendable {
    public var normalized: Point2D
    public var measured: Point2D
    public var estimated: Point2D
    public var errorMeters: Double { measured.distance(to: estimated) }
    public init?(imagePoint: Point2D, measured: Point2D, quad: StageQuad, size: StageSize) {
        guard size.isValid, let truth = size.normalized(from: measured), truth.isUnitPoint,
              let normalized = StageMapping(quad: quad)?.stagePoint(from: imagePoint), normalized.isUnitPoint else { return nil }
        // Calibration corners must not be presented as independent validation points.
        let corners = [Point2D(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]
        guard corners.allSatisfy({ $0.distance(to: normalized) > 0.08 }) else { return nil }
        self.normalized = normalized; self.measured = measured; estimated = size.meters(from: normalized)
    }
}
