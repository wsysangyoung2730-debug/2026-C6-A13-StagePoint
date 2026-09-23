import Foundation

public struct Point2D: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public var isFinite: Bool { x.isFinite && y.isFinite }
    public var isUnitPoint: Bool { isFinite && (0...1).contains(x) && (0...1).contains(y) }
    public func distance(to other: Self) -> Double { hypot(x - other.x, y - other.y) }
    public func clamped() -> Self { .init(x: min(1, max(0, x)), y: min(1, max(0, y))) }
}

public struct StageSize: Codable, Equatable, Sendable {
    public var width: Double
    public var depth: Double

    public init(width: Double, depth: Double) { self.width = width; self.depth = depth }
    public var isValid: Bool { width.isFinite && depth.isFinite && width > 0 && depth > 0 }
    public func meters(from normalized: Point2D) -> Point2D {
        .init(x: normalized.x * width, y: normalized.y * depth)
    }
    public func normalized(from meters: Point2D) -> Point2D? {
        guard isValid, meters.isFinite else { return nil }
        return .init(x: meters.x / width, y: meters.y / depth)
    }
}
