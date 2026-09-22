import SwiftUI
import UniformTypeIdentifiers
import StagePointCore

@MainActor
final class MeasurementStore: ObservableObject {
    @Published private(set) var records: [StageMeasurement] = []
    @Published var error: String?
    private let url: URL
    private var readable = true
    init() {
        let filename = ProcessInfo.processInfo.arguments.contains("--uitesting") ? "test-measurements.json" : "measurements.json"
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { records = try JSONDecoder().decode([StageMeasurement].self, from: Data(contentsOf: url)) }
        catch { self.error = error.localizedDescription; readable = false }
    }
    func append(_ record: StageMeasurement) throws {
        guard readable else { throw TemplateError.invalid("기존 측정 파일을 읽지 못해 덮어쓰기를 중단했습니다.") }
        let next = records + [record]
        try JSONEncoder().encode(next).write(to: url, options: .atomic)
        records = next
    }
}

struct MeasurementDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var records: [StageMeasurement]
    init(records: [StageMeasurement]) { self.records = records }
    init(configuration: ReadConfiguration) throws {
        records = try JSONDecoder().decode([StageMeasurement].self, from: configuration.file.regularFileContents ?? Data())
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(records))
    }
}

struct MeasurementPanel: View {
    @ObservedObject var model: StageSession
    @ObservedObject var store: MeasurementStore
    let isDemo: Bool
    @State private var xText = ""
    @State private var yText = ""
    @State private var exporting = false
    @State private var showHistory = false
    @State private var error: String?
    private var actual: Point2D? {
        guard let x = Double(xText), let y = Double(yText) else { return nil }
        return .init(x: x, y: y)
    }
    private var calculated: Point2D? { model.probe.map { model.stageSize.meters(from: $0) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("독립 검증점").font(.headline)
            Text("기준점으로 쓰지 않은 바닥 표식을 누르고 줄자로 잰 좌표를 입력하세요.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("실제 X m", text: $xText).accessibilityIdentifier("measurement-x")
                TextField("실제 Y m", text: $yText).accessibilityIdentifier("measurement-y")
            }.keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
            if let calculated {
                Text("계산 (\(calculated.x, specifier: "%.2f"), \(calculated.y, specifier: "%.2f")) m")
                    .font(.caption).monospacedDigit()
                if let actual {
                    Text("\(actual.distance(to: calculated) * 100, specifier: "%.1f") cm")
                        .font(.system(size: 29, weight: .semibold, design: .rounded)).foregroundStyle(.yellow)
                        .accessibilityIdentifier("measurement-error")
                }
            } else { Text("화면에서 검증점을 선택하세요.").font(.caption).foregroundStyle(.orange) }
            Button("측정 저장") { save() }.buttonStyle(.borderedProminent)
                .disabled(actual == nil || calculated == nil || model.mapping == nil)
                .accessibilityIdentifier("save-measurement")
            if let id = model.calibrationID, let summary = MeasurementSummary(measurements: store.records, calibrationID: id) {
                Text("현재 매핑 · \(summary.count)회").font(.caption.bold()).accessibilityIdentifier("measurement-count")
                Text("평균 \(summary.meanCentimeters, specifier: "%.1f") / 최대 \(summary.maximumCentimeters, specifier: "%.1f") cm")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("전체 기록") { showHistory = true }
                Button("내보내기") { exporting = true }.disabled(store.records.isEmpty)
            }.font(.caption)
            if isDemo { Text("데모 좌표 · 실제 정확도 아님").font(.caption).foregroundStyle(.orange) }
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.orange) }
        }
        .fileExporter(isPresented: $exporting, document: MeasurementDocument(records: store.records), contentType: .json, defaultFilename: "StagePoint-measurements") { result in
            if case .failure(let failure) = result { error = failure.localizedDescription }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                List(store.records.reversed()) { record in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(record.date, style: .time)
                            Text(record.isDemo ? "DEMO" : "카메라").foregroundStyle(record.isDemo ? .orange : .cyan)
                            Spacer(); Text("\(record.errorMeters * 100, specifier: "%.1f") cm")
                        }
                        Text("무대 \(record.stageSize.width, specifier: "%g") × \(record.stageSize.depth, specifier: "%g") m · 매핑 \(record.calibrationID.uuidString.prefix(6))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.navigationTitle("측정 기록").toolbar { Button("닫기") { showHistory = false } }
            }
        }
        .alert("측정 확인", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("확인", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    private func save() {
        guard let id = model.calibrationID, model.mapping != nil, let actual, let calculated else { return }
        do {
            let record = try StageMeasurement(calibrationID: id, stageSize: model.stageSize, quad: model.quad,
                                              actualMeters: actual, calculatedMeters: calculated, isDemo: isDemo,
                                              deviceDescription: "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion) · rear wide 1x")
            try store.append(record); model.probe = nil; model.message = "측정을 저장했습니다. 다음 검증점을 선택하세요."
        } catch { self.error = error.localizedDescription }
    }
}
