import Foundation

/// Image coordinates: top-left origin, normalized to 0...1.
/// Corner order: audience-front-left A, front-right B, back-right C, back-left D.
public struct StageQuad: Codable, Equatable, Sendable {
    public var corners: [Point2D]
    public init(corners: [Point2D]) { self.corners = corners }
    public static let manual = Self(corners: [
        .init(x: 0.12, y: 0.86), .init(x: 0.88, y: 0.86),
        .init(x: 0.74, y: 0.24), .init(x: 0.26, y: 0.24)
    ])
    public var isValid: Bool {
        guard corners.count == 4, corners.allSatisfy(\.isUnitPoint) else { return false }
        let crosses = (0..<4).map { i -> Double in
            let a = corners[i], b = corners[(i + 1) % 4], c = corners[(i + 2) % 4]
            return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
        }
        guard crosses.allSatisfy({ $0 > 0.0001 }) || crosses.allSatisfy({ $0 < -0.0001 }) else { return false }
        let area = abs((0..<4).reduce(0.0) { sum, i in
            let a = corners[i], b = corners[(i + 1) % 4]
            return sum + a.x * b.y - b.x * a.y
        }) / 2
        return area > 0.01
    }
}

/// A projective transform solved with partial-pivot Gaussian elimination.
/// Inputs are normalized coordinates to avoid metre/pixel conditioning problems.
public struct Homography: Sendable {
    private let h: [Double]

    public init?(source: [Point2D], destination: [Point2D]) {
        guard source.count == 4, destination.count == 4,
              source.allSatisfy(\.isFinite), destination.allSatisfy(\.isFinite) else { return nil }
        var a = [[Double]]()
        for (s, d) in zip(source, destination) {
            a.append([s.x, s.y, 1, 0, 0, 0, -d.x * s.x, -d.x * s.y, d.x])
            a.append([0, 0, 0, s.x, s.y, 1, -d.y * s.x, -d.y * s.y, d.y])
        }
        for col in 0..<8 {
            let pivot = (col..<8).max { abs(a[$0][col]) < abs(a[$1][col]) }!
            guard abs(a[pivot][col]) > 1e-10 else { return nil }
            a.swapAt(col, pivot)
            let divisor = a[col][col]
            for j in col...8 { a[col][j] /= divisor }
            for row in 0..<8 where row != col {
                let factor = a[row][col]
                for j in col...8 { a[row][j] -= factor * a[col][j] }
            }
        }
        let solution = a.map { $0[8] } + [1]
        guard solution.allSatisfy(\.isFinite) else { return nil }
        h = solution
    }

    public func project(_ point: Point2D) -> Point2D? {
        guard point.isFinite else { return nil }
        let denominator = h[6] * point.x + h[7] * point.y + h[8]
        guard abs(denominator) > 1e-10 else { return nil }
        let result = Point2D(x: (h[0] * point.x + h[1] * point.y + h[2]) / denominator,
                             y: (h[3] * point.x + h[4] * point.y + h[5]) / denominator)
        return result.isFinite ? result : nil
    }
}

public struct StageMapping: Sendable {
    public let quad: StageQuad
    private let toImage: Homography
    private let toStage: Homography
    private static let unit: [Point2D] = [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]

    public init?(quad: StageQuad) {
        guard quad.isValid,
              let forward = Homography(source: Self.unit, destination: quad.corners),
              let inverse = Homography(source: quad.corners, destination: Self.unit) else { return nil }
        self.quad = quad; toImage = forward; toStage = inverse
    }
    public func imagePoint(from normalized: Point2D) -> Point2D? { toImage.project(normalized) }
    public func stagePoint(from image: Point2D) -> Point2D? { toStage.project(image) }
}
