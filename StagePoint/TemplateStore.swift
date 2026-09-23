import SwiftUI
import UniformTypeIdentifiers
import StagePointCore

@MainActor
final class TemplateStore: ObservableObject {
    @Published private(set) var templates: [StageTemplate] = []
    @Published var error: String?
    private let url: URL
    private var readable = true

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = ProcessInfo.processInfo.arguments.contains("--uitesting") ? "test-stage-library.json" : "stage-library.json"
        url = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            templates = try JSONDecoder().decode([StageTemplate].self, from: Data(contentsOf: url))
            try templates.forEach { try $0.validate() }
        } catch { self.error = "기존 무대 파일을 읽을 수 없습니다: \(error.localizedDescription)"; readable = false; templates = [] }
    }
    func save(_ template: StageTemplate) throws {
        guard readable else { throw TemplateError.invalid("기존 저장 파일을 읽지 못해 덮어쓰기를 중단했습니다.") }
        try template.validate()
        var next = templates
        if let index = next.firstIndex(where: { $0.id == template.id }) { next[index] = template }
        else { next.insert(template, at: 0) }
        try JSONEncoder().encode(next).write(to: url, options: .atomic)
        templates = next
    }
    func importFile(_ url: URL) throws -> StageTemplate {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 1_000_000 else { throw TemplateError.invalid("표준 무대 파일은 1MB 이하만 지원합니다.") }
        var template = try StageTemplate.decode(Data(contentsOf: url))
        template.id = UUID() // An import never silently overwrites a stored template with the same ID.
        try save(template); return template
    }
}

struct TemplateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var template: StageTemplate
    init(template: StageTemplate) { self.template = template }
    init(configuration: ReadConfiguration) throws {
        template = try StageTemplate.decode(configuration.file.regularFileContents ?? Data())
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try template.encoded())
    }
}
