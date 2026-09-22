import SwiftUI
import StagePointCore

struct TemplateEditor: View {
    @ObservedObject var store: TemplateStore
    var onApply: (StageTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = StageTemplate.example
    @State private var width = "6.0"
    @State private var depth = "4.0"
    @State private var selectedID: UUID?
    @State private var xText = "2.0"
    @State private var yText = "3.0"
    @State private var importing = false
    @State private var exporting = false
    @State private var error: String?
    private var selectedIndex: Int { draft.targets.firstIndex(where: { $0.id == selectedID }) ?? 0 }
    private var valid: Bool { (try? draft.validate()) != nil }

    var body: some View {
        NavigationStack {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("표준 무대에 목표를 미리 찍어두세요").font(.headline)
                    Text("저장한 가로·세로 비율을 실제 무대에 그대로 배치합니다.").font(.caption).foregroundStyle(.secondary)
                    StagePlanView(size: draft.referenceSize, targets: draft.targets, selectedID: selectedID, onTap: moveTarget)
                        .accessibilityIdentifier("standard-plan")
                    HStack {
                        Menu("저장한 무대 \(store.templates.count)개", systemImage: "folder") {
                            ForEach(store.templates) { template in Button(template.name) { load(template) } }
                            if store.templates.isEmpty { Text("저장한 무대가 없습니다") }
                        }.accessibilityIdentifier("saved-templates")
                        Spacer()
                        Button("새 표준 무대") { load(.example) }.font(.caption)
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("표준 무대 이름", text: $draft.name).textFieldStyle(.roundedBorder).accessibilityIdentifier("template-name")
                        HStack {
                            input("가로 m", text: $width).accessibilityIdentifier("template-width")
                            input("세로 m", text: $depth).accessibilityIdentifier("template-depth")
                        }
                        .onChange(of: width) { _, _ in updateSize() }
                        .onChange(of: depth) { _, _ in updateSize() }
                        Picker("편집할 목표", selection: Binding(get: { selectedID ?? draft.targets[0].id }, set: { selectedID = $0; refreshCoordinates() })) {
                            ForEach(draft.targets) { target in Text(target.name).tag(target.id) }
                        }.pickerStyle(.menu)
                        HStack { input("X m", text: $xText); input("Y m", text: $yText) }
                        Button("목표 좌표 적용") {
                            guard let x = Double(xText), let y = Double(yText),
                                  let p = draft.referenceSize.normalized(from: .init(x: x, y: y)), p.isUnitPoint else {
                                error = "표준 무대 안쪽의 유효한 좌표를 입력하세요."; return
                            }
                            moveTarget(p)
                        }.buttonStyle(.bordered).accessibilityIdentifier("apply-standard-coordinate")
                        Button("목표 추가", systemImage: "plus.circle") {
                            let number = draft.targets.count + 1
                            let target = StageTarget(name: "목표 \(number)", normalized: .init(x: 0.5, y: 0.5))
                            draft.targets.append(target); selectedID = target.id; refreshCoordinates()
                        }.disabled(draft.targets.count >= 64)
                        Button("저장 후 무대에 배치") {
                            do { try store.save(draft); onApply(draft); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.buttonStyle(.borderedProminent).disabled(!valid)
                            .accessibilityIdentifier("save-and-place")
                        Text("파일은 기기에 저장됩니다. JSON으로 내보내 다른 기기에 가져올 수도 있습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let storeError = store.error { Text(storeError).font(.caption).foregroundStyle(.orange) }
                    }.padding(.trailing, 4)
                }.frame(width: 255)
            }.padding(18)
                .background(Color(red: 0.055, green: 0.07, blue: 0.09))
                .navigationTitle("표준 무대")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("가져오기", systemImage: "square.and.arrow.down") { importing = true }
                        Button("내보내기", systemImage: "square.and.arrow.up") { exporting = true }.disabled(!valid)
                    }
                }
        }
        .onAppear { selectedID = draft.targets[0].id }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do { load(try store.importFile(result.get())) } catch { self.error = error.localizedDescription }
        }
        .fileExporter(isPresented: $exporting, document: TemplateDocument(template: draft), contentType: .json, defaultFilename: "StagePoint-template") { result in
            if case .failure(let failure) = result { error = failure.localizedDescription }
        }
        .alert("확인해주세요", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("확인", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    private func input(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).monospacedDigit()
        }
    }
    private func moveTarget(_ point: Point2D) {
        draft.targets[selectedIndex].normalized = point; refreshCoordinates()
    }
    private func updateSize() {
        draft.referenceSize = .init(width: Double(width) ?? 0, depth: Double(depth) ?? 0)
        refreshCoordinates()
    }
    private func refreshCoordinates() {
        let point = draft.referenceSize.meters(from: draft.targets[selectedIndex].normalized)
        xText = String(format: "%.2f", point.x); yText = String(format: "%.2f", point.y)
    }
    private func load(_ template: StageTemplate) {
        draft = template; selectedID = template.targets[0].id
        width = String(format: "%g", template.referenceSize.width)
        depth = String(format: "%g", template.referenceSize.depth)
        refreshCoordinates()
    }
}
