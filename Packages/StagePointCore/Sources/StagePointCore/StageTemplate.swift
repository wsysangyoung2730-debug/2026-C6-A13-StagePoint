import Foundation

public struct StageTarget: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// x / stage width; y / stage depth. Origin is audience-front-left.
    public var normalized: Point2D
    public init(id: UUID = UUID(), name: String, normalized: Point2D) {
        self.id = id; self.name = name; self.normalized = normalized
    }
}

public enum TemplateError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public struct StageTemplate: Codable, Identifiable, Equatable, Sendable {
    public var version: Int
    public var id: UUID
    public var name: String
    public var referenceSize: StageSize
    public var targets: [StageTarget]

    public init(id: UUID = UUID(), name: String, referenceSize: StageSize, targets: [StageTarget]) {
        version = 1; self.id = id; self.name = name; self.referenceSize = referenceSize; self.targets = targets
    }
    public static var example: Self {
        Self(name: "표준 무대 6 × 4", referenceSize: .init(width: 6, depth: 4),
             targets: [.init(name: "목표 A", normalized: .init(x: 1.0 / 3.0, y: 0.75))])
    }
    public func validate() throws {
        guard version == 1 else { throw TemplateError.invalid("지원하지 않는 표준 무대 파일 버전입니다.") }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80 else {
            throw TemplateError.invalid("표준 무대 이름은 1~80자로 입력하세요.")
        }
        guard referenceSize.isValid, referenceSize.width <= 100, referenceSize.depth <= 100 else {
            throw TemplateError.invalid("표준 무대 치수는 0 초과~100m여야 합니다.")
        }
        guard (1...64).contains(targets.count), Set(targets.map(\.id)).count == targets.count,
              targets.allSatisfy({ $0.normalized.isUnitPoint && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 40 }) else {
            throw TemplateError.invalid("목표는 1~64개이며 서로 다른 ID와 무대 안쪽 좌표가 필요합니다.")
        }
    }
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 1_000_000 else { throw TemplateError.invalid("표준 무대 파일은 1MB 이하만 지원합니다.") }
        let template = try JSONDecoder().decode(Self.self, from: data)
        try template.validate(); return template
    }
}
