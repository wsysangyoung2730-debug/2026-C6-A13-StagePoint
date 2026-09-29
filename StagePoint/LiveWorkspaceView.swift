import SwiftUI
import RoomPlan
import StagePointCore

struct LiveWorkspaceView: View {
    @StateObject private var model: LiveSession
    let onExit: () -> Void
    init(role: DeviceRole, onExit: @escaping () -> Void) {
        _model = StateObject(wrappedValue: LiveSession(role: role)); self.onExit = onExit
    }
    var body: some View { LiveWorkspaceContent(model: model, rtc: model.rtc, onExit: onExit) }
}

private struct LiveWorkspaceContent: View {
    @ObservedObject var model: LiveSession
    @ObservedObject var rtc: LiveRTC
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var connectionSheet = true
    @State private var calibrationSheet = false
    @State private var now = Date()
    private let clock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private var fresh: Bool { model.demo || (rtc.dataReady && rtc.lastFrameAt.map { now.timeIntervalSince($0) < 3 } == true) }
    private var stateFresh: Bool { model.role == .camera || model.demo || model.lastSnapshotAt.map { now.timeIntervalSince($0) < 3 } == true }
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("나가기") { model.leave(); onExit() }
                Text(model.role == .camera ? "실시간 촬영" : "실시간 모니터링").font(.headline)
                Spacer()
                Text(model.demo ? "데모 · 실제 연결 아님" : rtc.status).font(.caption).foregroundStyle(rtc.dataReady ? .green : .secondary)
                Text("웨어러블 미사용").font(.caption).foregroundStyle(.secondary)
                Button("연결 설정") { connectionSheet = true }.accessibilityIdentifier("connection-settings")
            }
            if model.role == .monitor {
                monitor
            } else {
                camera
            }
            HStack {
                Text(model.message).lineLimit(2)
                Spacer()
                Text("1차 연구용 · 안전 보장 아님").foregroundStyle(.orange)
            }.font(.caption)
        }.padding(12).background(Color(.systemGroupedBackground))
            .sheet(isPresented: $connectionSheet) { ConnectionPanel(model: model, rtc: rtc) }
            .fullScreenCover(isPresented: $model.showScanner, onDismiss: {
                if model.snapshot.phase == "무대 스캔 중" { model.snapshot.phase = "스캔 취소 · 다시 시작하세요"; model.publish() }
            }) { RoomScannerView { model.scanned($0) }.preferredColorScheme(.dark) }
            .fullScreenCover(isPresented: $model.editingStage) {
                StageBoundsEditor(initial: model.draft?.size ?? .init(width: 8, depth: 6), source: model.draft?.rawRoom == nil ? "수동 입력" : "RoomPlan 측정 제안") { size in model.confirmStage(size) }
            }
            .fullScreenCover(isPresented: $calibrationSheet) {
                CalibrationEditor(model: model, rtc: rtc)
            }
            .onReceive(clock) { now = $0 }
            .task {
                if LiveTestConfiguration.role != nil { connectionSheet = false; model.startTransportFixture() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    model.showScanner = false; model.editingStage = false; calibrationSheet = false
                    model.invalidate("앱이 중단됐습니다. 재연결 후 다시 보정하세요."); rtc.disconnect()
                }
            }
            .onChange(of: rtc.videoSize) { previous, current in
                let oldRatio = previous.width / max(1, previous.height)
                let newRatio = current.width / max(1, current.height)
                if model.role == .camera, abs(oldRatio - newRatio) > 0.01, model.snapshot.calibration != nil {
                    model.invalidate("영상 비율·방향 변경 · 다시 보정하세요.")
                }
            }
    }
    private var camera: some View {
        VStack(spacing: 8) {
            HStack {
                Button("무대 스캔") { model.beginScan() }
                    .disabled(!rtc.dataReady || !RoomCaptureSession.isSupported || model.demo)
                Button("무대 크기 수동 설정") { model.manualStage() }.disabled(!rtc.dataReady && !model.demo)
                    .accessibilityIdentifier("manual-stage")
                Button("저장 스캔") { model.restoreScan() }.disabled(!rtc.dataReady && !model.demo)
                Spacer()
                Button("촬영 시작") { rtc.startCamera() }.disabled(!rtc.dataReady)
                Button("카메라 이동됨") { model.invalidate("카메라가 이동했습니다. 다시 보정하세요.") }.disabled(model.snapshot.calibration == nil)
                Button("기준점 보정") { calibrationSheet = true }.disabled(model.snapshot.stage == nil || !fresh)
                    .accessibilityIdentifier("open-calibration")
            }.buttonStyle(.bordered).font(.caption)
            video
                .overlay(alignment: .bottomLeading) {
                    HStack {
                        Text(model.snapshot.target == nil ? "목표 없음" : "목표 A")
                        Text(model.snapshot.canProject ? "보정 확인됨" : "보정 필요")
                    }.font(.caption2).padding(8).background(.regularMaterial, in: Capsule()).padding(12)
                }
            if !RoomCaptureSession.isSupported { Text("이 기기는 RoomPlan 미지원 · 수동 입력으로 흐름을 시험할 수 있습니다.").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private var monitor: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack {
                Text("무대 평면도").font(.headline)
                if let stage = model.snapshot.stage {
                    LivePlanView(size: stage.size, target: model.snapshot.target, enabled: model.snapshot.canProject && fresh && stateFresh && model.pendingCommand == nil) { model.setTarget($0) }
                    Text("\(stage.size.width, specifier: "%.1f") × \(stage.size.depth, specifier: "%.1f") m · \(stage.source)").font(.caption)
                } else {
                    ContentUnavailableView(model.snapshot.phase, systemImage: "viewfinder", description: Text("촬영 기기에서 스캔하고 공연 구역을 확정하면 여기에 표시됩니다."))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 14) {
                Text("카메라 실시간 영상").font(.headline)
                video.aspectRatio(16 / 9, contentMode: .fit)
                Text(model.snapshot.phase).font(.headline)
                Text("보정 완료 후 평면도를 터치하면 목표 A를 촬영 기기에 전달합니다.").font(.subheadline).foregroundStyle(.secondary)
                if !stateFresh { Text("무대 정보 갱신 대기 · 조작 중지").foregroundStyle(.orange) }
                Text("공연 불러오기·사람 추적은 2차 범위입니다.").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.frame(width: 300).padding().background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    private var video: some View {
        ZStack {
            if model.demo { Image(uiImage: DemoStage.image()).resizable().scaledToFit() }
            else { LiveVideoView(track: model.role == .camera ? rtc.localTrack : rtc.remoteTrack) }
            if fresh && stateFresh && model.snapshot.canProject, let calibration = model.snapshot.calibration {
                GeometryReader { geo in
                    ProjectionOverlay(quad: calibration.quad, target: model.snapshot.target,
                                      rect: AVFit.rect(aspect: model.demo ? DemoStage.image().size : rtc.videoSize, in: geo.size))
                }
            }
            if !fresh {
                Color.black.opacity(0.7)
                Text(rtc.lastFrameAt == nil ? "영상 대기 · 스캔 중에는 촬영하지 않습니다" : "영상 갱신 중단 · 마지막 화면")
                    .foregroundStyle(.white).font(.callout).multilineTextAlignment(.center).padding()
            }
        }.background(.black).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("live-video")
    }
}

private struct ConnectionPanel: View {
    @ObservedObject var model: LiveSession
    @ObservedObject var rtc: LiveRTC
    @Environment(\.dismiss) private var dismiss
    @AppStorage("live.endpoint") private var endpoint = "ws://192.168.0.10:8080"
    @AppStorage("live.room") private var room = "stagepoint"
    @State private var token = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("\(model.role.title) 연결") {
                    TextField("Mac 서버 주소", text: $endpoint).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("server-endpoint")
                    TextField("세션 이름", text: $room).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("연결 암호 · 12자 이상", text: $token)
                    Text("두 기기는 같은 Wi-Fi·세션 이름·연결 암호를 사용합니다. 암호는 저장하지 않습니다.").font(.caption)
                    Button("연결") { model.demo = false; rtc.connect(endpoint: endpoint, room: room, token: token, role: model.role) }.disabled(token.count < 12)
                    Text(rtc.status)
                    if rtc.joined { Button("작업 화면으로") { dismiss() }.disabled(!rtc.dataReady) }
                    Button("연결 종료") { rtc.disconnect() }
                }
                Section("장비") {
                    LabeledContent("RoomPlan", value: RoomCaptureSession.isSupported ? "지원 기기" : "미지원 · 수동 입력 가능")
                    LabeledContent("이어폰 · 비콘 · Watch", value: "이번 1차에서 사용 안 함")
                }
                Section("화면 시험") {
                    Button("연결 없이 데모 보기") {
                        rtc.disconnect(); model.demo = true
                        model.snapshot = LiveSnapshot()
                        model.snapshot.stage = LiveStage(size: .init(width: 8, depth: 6), source: "데모 · 실제 측정 아님", confirmed: true)
                        model.snapshot.phase = "카메라 고정·좌표 보정 대기"
                        model.message = "데모 화면입니다. 실제 영상·스캔·전송이 아닙니다."; dismiss()
                    }.accessibilityIdentifier("live-demo")
                }
            }.navigationTitle("기기 준비").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

struct LivePlanView: View {
    let size: StageSize
    let target: Point2D?
    let enabled: Bool
    let onTap: (Point2D) -> Void
    var body: some View {
        VStack(spacing: 8) {
            Text("무대 뒤").font(.caption)
            GeometryReader { geo in
                let rect = AVFit.rect(aspect: CGSize(width: size.width, height: size.depth), in: geo.size)
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        context.fill(Path(rect), with: .color(.blue.opacity(0.08)))
                        context.stroke(Path(rect), with: .color(.blue), lineWidth: 3)
                        var grid = Path()
                        for i in 1..<10 {
                            let fraction = Double(i) / 10
                            grid.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY)); grid.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
                            grid.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction)); grid.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
                        }
                        context.stroke(grid, with: .color(.blue.opacity(0.15)))
                    }
                    if let target {
                        Text("A").font(.headline).foregroundStyle(.white).frame(width: 30, height: 30).background(.blue, in: Circle())
                            .position(x: rect.minX + target.x * rect.width, y: rect.maxY - target.y * rect.height)
                    }
                }.contentShape(Rectangle()).onTapGesture { p in
                    guard enabled, rect.contains(p) else { return }
                    onTap(.init(x: (p.x - rect.minX) / rect.width, y: (rect.maxY - p.y) / rect.height))
                }
            }.accessibilityIdentifier("live-plan")
            Text("무대 앞 · 원점은 관객 기준 앞쪽 왼쪽").font(.caption)
        }
    }
}

enum AVFit {
    static func rect(aspect: CGSize, in available: CGSize) -> CGRect {
        let scale = min(available.width / max(1, aspect.width), available.height / max(1, aspect.height))
        let size = CGSize(width: aspect.width * scale, height: aspect.height * scale)
        return CGRect(x: (available.width - size.width) / 2, y: (available.height - size.height) / 2, width: size.width, height: size.height)
    }
}

struct StageBoundsEditor: View {
    let initial: StageSize
    let source: String
    let onConfirm: (StageSize) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var width = ""
    @State private var depth = ""
    @State private var checked = false
    private var size: StageSize { .init(width: Double(width) ?? 0, depth: Double(depth) ?? 0) }
    private var displaySize: StageSize {
        .init(width: size.width.isFinite ? min(100, max(0.5, size.width)) : 1,
              depth: size.depth.isFinite ? min(100, max(0.5, size.depth)) : 1)
    }
    var body: some View {
        NavigationStack {
            HStack(spacing: 20) {
                GeometryReader { geo in
                    let extent = CGSize(width: max(initial.width * 1.5, displaySize.width), height: max(initial.depth * 1.5, displaySize.depth))
                    let outer = AVFit.rect(aspect: extent, in: CGSize(width: geo.size.width - 50, height: geo.size.height - 50)).offsetBy(dx: 25, dy: 25)
                    let rect = CGRect(x: outer.minX, y: outer.maxY - outer.height * displaySize.depth / extent.height, width: outer.width * displaySize.width / extent.width, height: outer.height * displaySize.depth / extent.height)
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(.blue.opacity(0.08)).frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                        Path(rect).stroke(.blue, lineWidth: 3)
                        Text("무대 뒤").position(x: rect.midX, y: rect.minY - 15)
                        Text("무대 앞 · A").position(x: rect.midX, y: rect.maxY + 15)
                        ForEach(0..<4, id: \.self) { i in
                            let right = i == 1 || i == 2
                            let back = i >= 2
                            Circle().fill(.white).overlay(Circle().stroke(.blue, lineWidth: 3)).frame(width: 24, height: 24)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                                .position(x: right ? rect.maxX : rect.minX, y: back ? rect.minY : rect.maxY)
                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("bounds")).onChanged { value in
                                    let w = right ? value.location.x - rect.minX : rect.maxX - value.location.x
                                    let d = back ? rect.maxY - value.location.y : value.location.y - rect.minY
                                    width = String(format: "%.1f", min(100, max(0.5, w / outer.width * extent.width)))
                                    depth = String(format: "%.1f", min(100, max(0.5, d / outer.height * extent.height)))
                                    checked = false
                                })
                        }
                    }.coordinateSpace(name: "bounds").font(.caption)
                }
                Form {
                    Section(source) {
                        HStack { Text("가로(m)"); TextField("가로", text: $width).keyboardType(.decimalPad).accessibilityIdentifier("scan-width") }
                        HStack { Text("세로(m)"); TextField("세로", text: $depth).keyboardType(.decimalPad).accessibilityIdentifier("scan-depth") }
                        Button("너비와 깊이 바꾸기") { swap(&width, &depth); checked = false }
                    }
                    Section {
                        Text("직사각형 공연 구역을 지정합니다. 스캔된 방 전체가 무대는 아닙니다. 단차·비정형 무대는 이번 범위에서 제외합니다.").font(.caption)
                        Toggle("앞쪽 방향·경계를 직접 확인함", isOn: $checked).accessibilityIdentifier("confirm-bounds-check")
                        Button("무대 확정") { onConfirm(size) }.disabled(!checked || !size.isValid || size.width > 100 || size.depth > 100).accessibilityIdentifier("confirm-stage")
                    }
                }.frame(width: 300)
            }.padding().navigationTitle("무대 범위 수정").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }.onAppear { width = String(format: "%.1f", initial.width); depth = String(format: "%.1f", initial.depth) }
            .onChange(of: width) { _, _ in checked = false }.onChange(of: depth) { _, _ in checked = false }
    }
}
