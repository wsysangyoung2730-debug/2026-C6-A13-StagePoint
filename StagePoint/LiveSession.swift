import SwiftUI
import Combine
import StagePointCore

@MainActor
final class LiveSession: ObservableObject {
    let role: DeviceRole
    let rtc = LiveRTC()
    @Published var snapshot = LiveSnapshot()
    @Published var message = "두 기기를 연결하세요."
    @Published var draft: StageScanDraft?
    @Published var showScanner = false
    @Published var editingStage = false
    @Published var lastSnapshotAt: Date?
    @Published var demo = false
    private var receiver = SnapshotReceiver()
    private var subscriptions: Set<AnyCancellable> = []
    private var timer: AnyCancellable?
    private var processed: [UUID] = []
    @Published var pendingCommand: UUID?
    private var commandSentAt: Date?
    init(role: DeviceRole) {
        self.role = role
        rtc.onPacket = { [weak self] packet in self?.receive(packet) }
        rtc.onPeerReset = { [weak self] in
            guard let self else { return }
            self.receiver.reset(); self.lastSnapshotAt = nil; self.pendingCommand = nil
            self.snapshot.calibration = nil; self.snapshot.target = nil
            self.snapshot.phase = "연결 대기 · 재보정 필요"
            self.message = "연결 후 촬영 위치와 기준점을 다시 확인하세요."
        }
        rtc.$dataReady.removeDuplicates().sink { [weak self] ready in
            guard let self, ready else { return }
            DispatchQueue.main.async { self.publish() }
        }.store(in: &subscriptions)
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            if self.role == .camera, self.rtc.dataReady { self.publish() }
            if let sent = self.commandSentAt, Date().timeIntervalSince(sent) > 3, self.pendingCommand != nil {
                self.pendingCommand = nil; self.message = "목표 변경 응답 없음 · 현재 상태를 확인하세요."
            }
        }
    }
    func publish() {
        guard role == .camera else { return }
        snapshot.revision += 1
        rtc.send(LivePacket(snapshot: snapshot))
    }
    func beginScan() {
        snapshot.calibration = nil; snapshot.target = nil; snapshot.stage = nil
        snapshot.phase = "무대 스캔 중"; publish()
        rtc.stopCamera { [weak self] in self?.showScanner = true }
    }
    func scanned(_ result: ScanResult) {
        showScanner = false
        switch result {
        case .success(let draft):
            self.draft = draft; editingStage = true; snapshot.phase = "무대 범위 확인 중"
            do { try StageScanArchive.save(draft); message = "스캔 원본 저장됨 · 실제 공연 구역을 확인하세요." }
            catch { message = "스캔은 완료됐지만 저장 실패: \(error.localizedDescription)" }
        case .failure(let reason): snapshot.phase = "스캔 실패"; message = reason
        }
        publish()
    }
    func manualStage() {
        snapshot.calibration = nil; snapshot.target = nil
        draft = StageScanDraft(size: snapshot.stage?.size ?? .init(width: 8, depth: 6), floorPolygon: [], floorTransform: [], rawRoom: nil)
        editingStage = true; snapshot.phase = "무대 범위 확인 중"; publish()
    }
    func restoreScan() {
        do { draft = try StageScanArchive.load(); editingStage = true; snapshot.calibration = nil; snapshot.target = nil; snapshot.phase = "저장 스캔 재확인"; publish() }
        catch { message = "저장한 스캔을 불러올 수 없습니다." }
    }
    func confirmStage(_ size: StageSize) {
        let stage = LiveStage(size: size, source: draft?.rawRoom == nil ? "수동 입력" : "RoomPlan 제안 + 사람 확인", confirmed: true)
        guard stage.isValid else { message = "무대 크기는 0 초과~100m로 입력하세요."; return }
        snapshot.stage = stage; snapshot.calibration = nil; snapshot.target = nil
        snapshot.phase = "카메라 고정·좌표 보정 대기"; editingStage = false
        message = "iPhone을 고정하고 기준점 보정을 진행하세요."
        publish(); rtc.startCamera()
    }
    func invalidate(_ reason: String) {
        snapshot.calibration = nil; snapshot.target = nil; snapshot.phase = "재보정 필요"
        message = reason; publish()
    }
    func leave() { rtc.disconnect(); timer?.cancel() }
    private func receive(_ packet: LivePacket) {
        if role == .monitor, let next = packet.snapshot, receiver.accept(next) {
            snapshot = next; lastSnapshotAt = Date()
        }
        if let id = packet.acknowledgedID, id == pendingCommand {
            pendingCommand = nil; message = packet.error ?? "촬영 기기에 목표 A가 반영됐습니다."
        }
        if role == .camera, let command = packet.command {
            guard command.sessionID == snapshot.sessionID, command.calibrationID == snapshot.calibration?.id,
                  snapshot.canProject else { rtc.send(LivePacket(acknowledgedID: command.id, error: "무대 보정 상태가 바뀌었습니다.")); return }
            if !processed.contains(command.id) {
                snapshot.target = command.target; processed.append(command.id)
                if processed.count > 128 { processed.removeFirst() }
            }
            publish(); rtc.send(LivePacket(acknowledgedID: command.id))
        }
    }
    func setTarget(_ target: Point2D) {
        guard target.isUnitPoint, snapshot.canProject else { return }
        if demo || role == .camera { snapshot.target = target; publish(); return }
        guard pendingCommand == nil, let calibration = snapshot.calibration else { return }
        let command = LiveCommand(sessionID: snapshot.sessionID, calibrationID: calibration.id, target: target)
        if rtc.send(LivePacket(command: command)) {
            pendingCommand = command.id; commandSentAt = Date(); message = "목표 A 전달 중…"
        } else { message = "연결을 확인하세요." }
    }
}
