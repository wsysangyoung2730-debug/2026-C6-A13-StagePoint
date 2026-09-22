import SwiftUI
import StagePointCore

struct ContentView: View {
    @StateObject private var camera = CameraController()
    @StateObject private var model = StageSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var demo = ProcessInfo.processInfo.arguments.contains("--demo")
    @State private var sample = DemoStage.image()
    private var currentFrame: UIImage? { demo ? sample : camera.frame }

    var body: some View {
        VStack(spacing: 10) {
            header
            HStack(alignment: .top, spacing: 12) {
                StageCanvas(model: model, image: model.frozenFrame ?? currentFrame)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if model.mode == .mapping { mappingPanel } else { pointPanel }
                    }.padding(16)
                }.frame(width: 245).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            }
            HStack {
                Label(demo ? "데모 · 실제 측정 아님" : camera.message, systemImage: demo ? "testtube.2" : "camera")
                Spacer()
                Text("원점 A · 관객 기준 앞쪽 왼쪽").foregroundStyle(.secondary)
            }.font(.system(size: 11))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(red: 0.055, green: 0.07, blue: 0.09))
        .tint(.cyan)
        .task {
            #if targetEnvironment(simulator)
            demo = true
            #endif
            if demo { model.detect(sample) } else { camera.start() }
        }
        .onChange(of: camera.frame) { _, frame in
            if !demo, model.frozenFrame == nil, model.mapping == nil, model.proposals.isEmpty,
               !model.isDetecting, let frame { model.detect(frame) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                camera.stop(); model.invalidate("앱이 중단됐습니다. 카메라 위치 확인 후 다시 매핑하세요.")
            } else if !demo { camera.start() }
        }
    }
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "viewfinder").foregroundStyle(.cyan).font(.title3)
            Text("StagePoint").font(.system(size: 21, weight: .bold, design: .rounded))
            Divider().frame(height: 20)
            ForEach([WorkspaceMode.mapping, .points], id: \.self) { mode in
                Button(mode.rawValue) { model.mode = mode }.buttonStyle(.bordered)
                    .tint(model.mode == mode ? .cyan : .gray)
                    .disabled(mode != .mapping && model.mapping == nil)
            }
            Spacer(minLength: 0)
            Button(demo ? "카메라" : "데모") {
                demo.toggle(); model.manual(frame: demo ? sample : nil)
                if demo { camera.stop(); model.detect(sample) } else { camera.start() }
            }.buttonStyle(.bordered)
            if camera.unavailable && !demo {
                Button("설정") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            }
        }
    }
    private var mappingPanel: some View {
        Group {
            Text("무대 기준점").font(.headline)
            HStack {
                Button { if let image = currentFrame { model.detect(image) } } label: {
                    Label(model.isDetecting ? "인식 중" : "자동 제안", systemImage: "viewfinder")
                }.buttonStyle(.borderedProminent).disabled(currentFrame == nil || model.isDetecting)
                Button("수동") { model.manual(frame: currentFrame) }.buttonStyle(.bordered)
            }
            if !model.proposals.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(model.proposals.enumerated()), id: \.element.id) { i, proposal in
                            Button("후보 \(i + 1)") { model.select(proposal) }
                                .buttonStyle(.bordered).tint(model.selectedProposal == proposal.id ? .cyan : .gray)
                        }
                    }
                }
            }
            Text("자동 인식은 사각형 후보입니다. 바닥인지 확인하고 네 점을 손으로 옮기세요.")
                .font(.caption).foregroundStyle(.secondary)
            dimensionField("가로", text: $model.widthText)
            dimensionField("세로", text: $model.depthText)
            Button("앞쪽 A·B 전환", systemImage: "arrow.triangle.2.circlepath") { model.flipFront() }.font(.caption)
            Button("매핑 적용") { model.apply() }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                .disabled(!model.quad.isValid || !model.stageSize.isValid || model.isDetecting || currentFrame == nil)
                .accessibilityIdentifier("apply-mapping")
        }
    }
    private var pointPanel: some View {
        Group {
            Text("목표 A").font(.headline)
            Text("카메라 화면의 바닥을 누르세요.").font(.caption).foregroundStyle(.secondary)
            if let target = model.target {
                let meters = model.stageSize.meters(from: target)
                Text("X  \(meters.x, specifier: "%.2f") m").monospacedDigit()
                Text("Y  \(meters.y, specifier: "%.2f") m").monospacedDigit()
                Text("비율 \(target.x * 100, specifier: "%.1f")% · \(target.y * 100, specifier: "%.1f")%")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("기준점 다시 조정") { model.mode = .mapping }
            Button(model.frozenFrame == nil ? "화면 정지" : "실시간 보기") {
                model.frozenFrame = model.frozenFrame == nil ? currentFrame : nil
            }.buttonStyle(.bordered)
            Text("카메라가 움직였다면 반드시 다시 매핑하세요.").font(.caption).foregroundStyle(.orange)
        }
    }
    private func dimensionField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(.subheadline)
            TextField(title, text: text).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).monospacedDigit()
                .onChange(of: text.wrappedValue) { _, _ in model.invalidate("무대 치수가 변경됐습니다. 다시 적용하세요.") }
            Text("m").foregroundStyle(.secondary)
        }
    }
}
