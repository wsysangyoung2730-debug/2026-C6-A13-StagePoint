import SwiftUI
import StagePointCore

struct CalibrationEditor: View {
    @ObservedObject var model: LiveSession
    @ObservedObject var rtc: LiveRTC
    @Environment(\.dismiss) private var dismiss
    @State private var quad = StageQuad.manual
    @State private var checking = false
    @State private var selectedCorner = 0
    @State private var probe: Point2D?
    @State private var actualX = ""
    @State private var actualY = ""
    @State private var samples: [CalibrationProbe] = []
    @State private var acknowledged = false
    @State private var notice = "A=앞쪽 왼쪽, B=앞쪽 오른쪽, C=뒤쪽 오른쪽, D=뒤쪽 왼쪽"
    @State private var stageID: UUID?
    private var ready: Bool { model.demo || (rtc.dataReady && rtc.lastFrameAt.map { Date().timeIntervalSince($0) < 3 } == true) }
    var body: some View {
        NavigationStack {
            HStack(spacing: 12) {
                GeometryReader { geometry in
                    let aspect = model.demo ? DemoStage.image().size : rtc.videoSize
                    let rect = AVFit.rect(aspect: aspect, in: geometry.size)
                    ZStack(alignment: .topLeading) {
                        if model.demo { Image(uiImage: DemoStage.image()).resizable().scaledToFit().frame(width: geometry.size.width, height: geometry.size.height) }
                        else { LiveVideoView(track: rtc.localTrack) }
                        ProjectionOverlay(quad: quad, target: nil, rect: rect)
                        if !checking {
                            ForEach(0..<4, id: \.self) { index in
                                Text(["A", "B", "C", "D"][index]).font(.headline).foregroundStyle(.white)
                                    .frame(width: 30, height: 30).background(index == selectedCorner ? .orange : .blue, in: Circle())
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                                    .position(quad.corners[index].screen(in: rect))
                                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("live-calibration")).onChanged { event in
                                        selectedCorner = index
                                        quad.corners[index] = Point2D(x: (event.location.x - rect.minX) / rect.width, y: (event.location.y - rect.minY) / rect.height).clamped()
                                    }).accessibilityElement().accessibilityLabel("기준점 \(["A", "B", "C", "D"][index])")
                                    .accessibilityAddTraits(.isButton).accessibilityIdentifier("live-corner-\(index)")
                            }
                        }
                        if let probe {
                            Image(systemName: "plus.viewfinder").font(.title).foregroundStyle(.yellow).position(probe.screen(in: rect))
                        }
                    }.coordinateSpace(name: "live-calibration").contentShape(Rectangle())
                        .onTapGesture { point in
                            guard checking, ready, rect.contains(point) else { return }
                            probe = .init(x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
                        }
                        .background(.black).clipped().accessibilityElement(children: .contain).accessibilityIdentifier("calibration-video")
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(checking ? "독립 검증점 확인" : "네 기준점 정렬").font(.headline)
                        Text(notice).font(.caption)
                        if checking {
                            Text("기준점과 다른 바닥 표식을 3곳 이상 선택하세요. 중앙·먼 곳·가장자리를 나눠 확인합니다.").font(.caption)
                            TextField("실측 X(m)", text: $actualX).keyboardType(.decimalPad).accessibilityIdentifier("probe-x")
                            TextField("실측 Y(m)", text: $actualY).keyboardType(.decimalPad).accessibilityIdentifier("probe-y")
                            Button("검증점 기록") { record() }.disabled(probe == nil || !ready).accessibilityIdentifier("record-probe")
                            ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                                Text("\(index + 1)번 오차: \(sample.errorMeters * 100, specifier: "%.1f") cm").font(.caption).monospacedDigit()
                            }
                            Text("오차 수치는 안전 판정이 아닙니다. 현장에서 허용 가능한지 직접 확인하세요.").font(.caption).foregroundStyle(.orange)
                            Toggle("오차·앞쪽 방향을 직접 확인함", isOn: $acknowledged).font(.caption)
                            Button("보정 확정") { finish() }.disabled(samples.count < 3 || !acknowledged || !ready).buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("finish-calibration")
                            Button("기준점 다시 조정") { checking = false; samples = []; probe = nil; acknowledged = false }
                        } else {
                            Text("카메라를 고정한 상태에서 네 점을 무대 바닥 모서리에 맞추세요. 화면의 벽·높은 소품에는 맞추지 마세요.").font(.caption)
                            Picker("기준점", selection: $selectedCorner) { ForEach(0..<4, id: \.self) { Text(["A", "B", "C", "D"][$0]).tag($0) } }.pickerStyle(.segmented)
                            HStack {
                                ForEach(0..<4, id: \.self) { i in
                                    Button(["←", "→", "↑", "↓"][i]) {
                                        let p = quad.corners[selectedCorner]
                                        quad.corners[selectedCorner] = Point2D(x: p.x + [-0.002, 0.002, 0, 0][i], y: p.y + [0, 0, -0.002, 0.002][i]).clamped()
                                    }.buttonStyle(.bordered)
                                }
                            }
                            Button("앞·뒤 방향 전환") { quad.corners = Array(quad.corners[2...]) + Array(quad.corners[..<2]) }
                            Button("검증 단계로") { checking = true }.disabled(!quad.isValid || !ready).buttonStyle(.borderedProminent).accessibilityIdentifier("validate-calibration")
                        }
                    }.padding(12)
                }.frame(width: 260).textFieldStyle(.roundedBorder)
            }.padding(12).navigationTitle("영상–무대 좌표 보정").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }.onAppear { stageID = model.snapshot.stage?.id; model.invalidate("기준점 보정 중 · 기존 목표 표시 중지") }
            .onChange(of: rtc.videoSize) { previous, current in
                guard abs(previous.width / max(1, previous.height) - current.width / max(1, current.height)) > 0.01 else { return }
                checking = false; samples = []; acknowledged = false
                notice = "영상 방향·비율이 바뀌었습니다. 기준점부터 다시 확인하세요."
            }
            .onChange(of: rtc.dataReady) { _, ready in if !ready && !model.demo { dismiss() } }
    }
    private func record() {
        guard let probe, let x = Double(actualX), let y = Double(actualY), let size = model.snapshot.stage?.size,
              let sample = CalibrationProbe(imagePoint: probe, measured: .init(x: x, y: y), quad: quad, size: size),
              samples.allSatisfy({ $0.normalized.distance(to: sample.normalized) > 0.1 }) else {
            notice = "무대 내부의 서로 떨어진 검증점을 선택하고 실측 좌표를 입력하세요."; return
        }
        samples.append(sample); self.probe = nil; acknowledged = false
        notice = "\(samples.count)개 지점 기록됨"
    }
    private func finish() {
        guard ready, let stage = model.snapshot.stage, stage.id == stageID, samples.count >= 3 else { return }
        var calibration = LiveCalibration(stage: stage, quad: quad); calibration.validated = true
        model.snapshot.calibration = calibration; model.snapshot.phase = "실시간 모니터링"
        model.snapshot.target = .init(x: 0.5, y: 0.5)
        model.message = "기준점 확인됨 · 카메라를 움직이면 다시 보정하세요."
        model.publish()
        do {
            let record = CalibrationArchive(calibration: calibration, stage: stage, samples: samples, isDemo: model.demo)
            try record.save()
        } catch { model.message = "보정 적용됨 · 검증 기록 저장 실패: \(error.localizedDescription)" }
        dismiss()
    }
}

struct ProjectionOverlay: View {
    let quad: StageQuad
    let target: Point2D?
    let rect: CGRect
    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                guard let mapping = StageMapping(quad: quad) else { return }
                var boundary = Path()
                for (index, point) in quad.corners.enumerated() {
                    if index == 0 { boundary.move(to: point.screen(in: rect)) } else { boundary.addLine(to: point.screen(in: rect)) }
                }
                boundary.closeSubpath()
                context.fill(boundary, with: .color(.blue.opacity(0.12)))
                context.stroke(boundary, with: .color(.blue), lineWidth: 2)
                var grid = Path()
                for i in 1..<8 {
                    let t = Double(i) / 8
                    for (a, b) in [(Point2D(x: t, y: 0), Point2D(x: t, y: 1)), (.init(x: 0, y: t), .init(x: 1, y: t))] {
                        if let a = mapping.imagePoint(from: a), let b = mapping.imagePoint(from: b) {
                            grid.move(to: a.screen(in: rect)); grid.addLine(to: b.screen(in: rect))
                        }
                    }
                }
                context.stroke(grid, with: .color(.blue.opacity(0.35)))
            }
            if let target, let point = StageMapping(quad: quad)?.imagePoint(from: target), point.isUnitPoint {
                Text("A").font(.headline).foregroundStyle(.white).frame(width: 28, height: 28).background(.blue, in: Circle()).position(point.screen(in: rect))
            }
        }.allowsHitTesting(false)
    }
}

private struct CalibrationArchive: Codable {
    let calibration: LiveCalibration
    let stage: LiveStage
    let samples: [CalibrationProbe]
    let isDemo: Bool
    var recordedAt = Date()
    func save() throws {
        let directory = StageScanArchive.url.deletingLastPathComponent().appendingPathComponent("calibrations", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: directory.appendingPathComponent("\(calibration.id).json"), options: .atomic)
    }
}
