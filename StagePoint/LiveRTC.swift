import AVFoundation
import Combine
import StagePointCore
import SwiftUI
import WebRTC

/// All connection state is serialized on the main queue; capture is owned by one WebRTC capturer.
final class LiveRTC: NSObject, ObservableObject {
    @Published var status = "연결 대기"
    @Published var dataReady = false
    @Published var joined = false
    @Published var localTrack: RTCVideoTrack?
    @Published var remoteTrack: RTCVideoTrack?
    @Published var lastFrameAt: Date?
    @Published var videoSize = CGSize(width: 1280, height: 720)
    var onPacket: ((LivePacket) -> Void)?
    var onPeerReset: (() -> Void)?
    private let factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory())
    private var peer: RTCPeerConnection?
    private var channel: RTCDataChannel?
    private var socket: URLSessionWebSocketTask?
    private var capturer: RTCCameraVideoCapturer?
    private var candidates: [RTCIceCandidate] = []
    private var generation = UUID()
    private var epoch = ""
    private var role: DeviceRole = .camera
    private var isCapturing = false
    private var captureGeneration = UUID()
    private lazy var pulse = FramePulse { [weak self] size in
        self?.lastFrameAt = Date(); self?.videoSize = size
    }

    func connect(endpoint: String, room: String, token: String, role: DeviceRole) {
        disconnect()
        guard let url = URL(string: endpoint), ["ws", "wss"].contains(url.scheme ?? ""),
              url.host != nil, room.range(of: "^[A-Za-z0-9-]{4,32}$", options: .regularExpression) != nil,
              (12...128).contains(token.count) else {
            status = "서버 주소·세션 이름·12자 이상 연결 암호를 확인하세요."; return
        }
        self.role = role; status = "서버 연결 중"
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task; task.resume()
        signal(["type": "join", "room": room, "token": token, "role": role.rawValue])
        receive(task, generation: generation)
    }

    func disconnect() {
        generation = UUID()
        socket?.cancel(with: .normalClosure, reason: nil); socket = nil
        resetPeer(); joined = false; status = "연결 대기"
    }

    private func resetPeer() {
        stopCamera()
        localTrack?.remove(pulse); remoteTrack?.remove(pulse)
        channel?.delegate = nil; channel?.close(); channel = nil
        peer?.close(); peer = nil
        localTrack = nil; remoteTrack = nil; dataReady = false
        lastFrameAt = nil; candidates = []; epoch = ""
        onPeerReset?()
    }

    private func receive(_ task: URLSessionWebSocketTask, generation expected: UUID) {
        task.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.generation == expected else { return }
                switch result {
                case .failure:
                    self.resetPeer(); self.joined = false
                    self.status = "연결 끊김 · 서버와 Wi-Fi 확인 후 다시 연결하세요."
                case .success(let message):
                    let data: Data?
                    switch message { case .data(let bytes): data = bytes; case .string(let text): data = text.data(using: .utf8); @unknown default: data = nil }
                    if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { self.handle(json) }
                    self.receive(task, generation: expected)
                }
            }
        }
    }

    private func signal(_ value: [String: Any]) {
        guard let bytes = try? JSONSerialization.data(withJSONObject: value), let text = String(data: bytes, encoding: .utf8) else { return }
        let expected = generation
        socket?.send(.string(text)) { [weak self] error in
            guard error != nil else { return }
            DispatchQueue.main.async {
                guard let self, self.generation == expected else { return }
                self.status = "연결 메시지 전송 실패 · 다시 연결하세요."
            }
        }
    }

    private func handle(_ json: [String: Any]) {
        guard let type = json["type"] as? String else { return }
        switch type {
        case "joined": joined = true; status = "상대 기기 대기 중"
        case "ready":
            resetPeer(); epoch = json["epoch"] as? String ?? ""
            makePeer()
            if role == .camera { negotiateOffer() }
        case "peer-left": resetPeer(); status = "상대 기기 연결 끊김 · 재접속 대기"
        case "error": status = json["message"] as? String ?? "연결 거절"
        case "offer", "answer":
            guard json["epoch"] as? String == epoch, let sdp = json["sdp"] as? String, let connection = peer else { return }
            let description = RTCSessionDescription(type: type == "offer" ? .offer : .answer, sdp: sdp)
            connection.setRemoteDescription(description) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self, self.peer === connection else { return }
                    guard error == nil else { self.status = "연결 협상 실패"; return }
                    self.candidates.forEach { connection.add($0) { _ in } }; self.candidates = []
                    if type == "offer" {
                        connection.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)) { [weak self] sdp, error in
                            DispatchQueue.main.async { if error == nil, let sdp { self?.publish(sdp, connection: connection) } }
                        }
                    }
                }
            }
        case "candidate":
            guard json["epoch"] as? String == epoch, let sdp = json["candidate"] as? String,
                  let index = json["sdpMLineIndex"] as? Int32 else { return }
            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: index, sdpMid: json["sdpMid"] as? String)
            if peer?.remoteDescription == nil { if candidates.count < 256 { candidates.append(candidate) } }
            else { peer?.add(candidate) { _ in } }
        default: break
        }
    }

    private func makePeer() {
        let configuration = RTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        // LAN prototype: no third-party STUN/TURN service or credentials.
        configuration.iceServers = []
        peer = factory.peerConnection(with: configuration, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self)
        if role == .camera {
            let source = factory.videoSource()
            capturer = RTCCameraVideoCapturer(delegate: source)
            let track = factory.videoTrack(with: source, trackId: "stage-camera")
            localTrack = track; track.add(pulse)
            peer?.add(track, streamIds: ["stage"])
            let config = RTCDataChannelConfiguration(); config.isOrdered = true
            channel = peer?.dataChannel(forLabel: "stage-control", configuration: config)
            channel?.delegate = self
        }
        status = "기기 연결 협상 중"
    }

    private func negotiateOffer() {
        guard let connection = peer else { return }
        connection.offer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)) { [weak self] sdp, error in
            DispatchQueue.main.async { if error == nil, let sdp { self?.publish(sdp, connection: connection) } }
        }
    }
    private func publish(_ sdp: RTCSessionDescription, connection: RTCPeerConnection) {
        guard peer === connection else { return }
        connection.setLocalDescription(sdp) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.peer === connection, error == nil else { return }
                self.signal(["type": sdp.type == .offer ? "offer" : "answer", "sdp": sdp.sdp, "epoch": self.epoch])
            }
        }
    }

    func startCamera() {
        guard role == .camera, !isCapturing, let capturer else { return }
        let request = UUID(); captureGeneration = request
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self, self.captureGeneration == request else { return }
                guard allowed else { self.status = "설정에서 카메라 권한을 허용하세요."; return }
                guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .back }),
                      let format = RTCCameraVideoCapturer.supportedFormats(for: device).min(by: { a, b in
                          func score(_ format: AVCaptureDevice.Format) -> Int {
                              let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                              return abs(Int(size.width) - 1280) + abs(Int(size.height) - 720)
                          }
                          return score(a) < score(b)
                      }) else { self.status = "후면 카메라를 사용할 수 없습니다."; return }
                let maxFPS = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
                self.isCapturing = true
                capturer.startCapture(with: device, format: format, fps: min(30, Int(maxFPS))) { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self, self.captureGeneration == request else { return }
                        if let error { self.isCapturing = false; self.status = error.localizedDescription }
                    }
                }
            }
        }
    }
    func stopCamera(completion: (() -> Void)? = nil) {
        captureGeneration = UUID(); isCapturing = false; lastFrameAt = nil
        guard let capturer else { completion?(); return }
        capturer.stopCapture { DispatchQueue.main.async { completion?() } }
    }
    @discardableResult func send(_ packet: LivePacket) -> Bool {
        guard dataReady, let channel, channel.bufferedAmount < 128_000, let data = try? packet.encoded() else { return false }
        return channel.sendData(RTCDataBuffer(data: data, isBinary: true))
    }
}

extension LiveRTC: RTCPeerConnectionDelegate {
    func peerConnection(_ p: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ p: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ p: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ p: RTCPeerConnection) {}
    func peerConnection(_ p: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ p: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ p: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.peer === p else { return }
            self.signal(["type": "candidate", "candidate": candidate.sdp, "sdpMid": candidate.sdpMid ?? "0", "sdpMLineIndex": candidate.sdpMLineIndex, "epoch": self.epoch])
        }
    }
    func peerConnection(_ p: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.peer === p else { return }
            if newState == .connected || newState == .completed { self.status = "기기 연결됨" }
            if [.failed, .disconnected, .closed].contains(newState) {
                self.dataReady = false; self.lastFrameAt = nil
                self.status = "통신 중단 · 다시 연결하세요."; self.onPeerReset?()
            }
        }
    }
    func peerConnection(_ p: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.peer === p else { return }
            self.channel = dataChannel; dataChannel.delegate = self
            self.dataReady = dataChannel.readyState == .open
        }
    }
    func peerConnection(_ p: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.peer === p, let track = rtpReceiver.track as? RTCVideoTrack else { return }
            self.remoteTrack?.remove(self.pulse); self.remoteTrack = track; track.add(self.pulse)
        }
    }
}
extension LiveRTC: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.channel === dataChannel else { return }
            self.dataReady = dataChannel.readyState == .open
        }
    }
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard let packet = try? LivePacket.decode(buffer.data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.channel === dataChannel else { return }
            self.onPacket?(packet)
        }
    }
}

private final class FramePulse: NSObject, RTCVideoRenderer {
    let callback: (CGSize) -> Void
    private var last = Date.distantPast
    private let lock = NSLock()
    init(callback: @escaping (CGSize) -> Void) { self.callback = callback }
    func setSize(_ size: CGSize) {}
    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame else { return }
        lock.lock()
        let now = Date(); let emit = now.timeIntervalSince(last) > 0.25
        if emit { last = now }; lock.unlock()
        guard emit else { return }
        let rotated = frame.rotation == ._90 || frame.rotation == ._270
        let size = CGSize(width: Int(rotated ? frame.height : frame.width), height: Int(rotated ? frame.width : frame.height))
        DispatchQueue.main.async { self.callback(size) }
    }
}

struct LiveVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero); view.videoContentMode = .scaleAspectFit
        view.backgroundColor = .black; return view
    }
    func updateUIView(_ view: RTCMTLVideoView, context: Context) {
        guard context.coordinator.track !== track else { return }
        context.coordinator.track?.remove(view); context.coordinator.track = track
        view.renderFrame(nil); track?.add(view)
    }
    static func dismantleUIView(_ view: RTCMTLVideoView, coordinator: Coordinator) { coordinator.track?.remove(view) }
    final class Coordinator { var track: RTCVideoTrack? }
}
