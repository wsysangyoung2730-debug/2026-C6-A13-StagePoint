import SwiftUI
import StagePointCore

struct DeviceRoleView: View {
    @State private var role: DeviceRole?
    @State private var legacy = false
    var body: some View {
        if legacy {
            VStack(spacing: 0) {
                Button("기기 역할 선택으로") { legacy = false }.padding(6)
                ContentView()
            }
        } else if let role {
            DeviceWorkspace(role: role) { self.role = nil }
        } else {
            VStack(spacing: 22) {
                Text("StagePoint").font(.largeTitle.bold())
                Text("1차 · 무대 스캔과 두 기기 모니터링").foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    ForEach(DeviceRole.allCases, id: \.self) { value in
                        Button { role = value } label: {
                            VStack(spacing: 14) {
                                Image(systemName: value == .camera ? "iphone" : "ipad.landscape").font(.largeTitle)
                                Text(value.title).font(.headline)
                                Text(value == .camera ? "무대 스캔 · 촬영 · 좌표 보정" : "영상 수신 · 평면도 · 목표 지정").font(.caption)
                            }.frame(maxWidth: .infinity).padding(24)
                        }.buttonStyle(.bordered).accessibilityIdentifier("role-\(value.rawValue)")
                    }
                }
                Button("기존 단일 기기 매핑 도구") { legacy = true }
                Text("연구용 시제품 · 이어폰·비콘·사람 추적은 포함하지 않습니다.").font(.caption).foregroundStyle(.orange)
            }.padding(30)
        }
    }
}

struct DeviceWorkspace: View {
    let role: DeviceRole
    let onExit: () -> Void
    @StateObject private var rtc = LiveRTC()
    @State private var endpoint = "ws://192.168.0.10:8080"
    @State private var room = "stagepoint"
    @State private var token = ""
    var body: some View {
        VStack(spacing: 12) {
            HStack { Text(role.title).font(.headline); Spacer(); Text(rtc.status); Button("나가기") { rtc.disconnect(); onExit() } }
            if !rtc.joined {
                TextField("시그널링 서버 주소", text: $endpoint).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("세션 이름", text: $room).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("두 기기에서 동일한 연결 암호 · 12자 이상", text: $token)
                Button("연결") { rtc.connect(endpoint: endpoint, room: room, token: token, role: role) }.buttonStyle(.borderedProminent)
            }
            LiveVideoView(track: role == .camera ? rtc.localTrack : rtc.remoteTrack)
            HStack {
                if role == .camera { Button("촬영 시작") { rtc.startCamera() }.disabled(!rtc.dataReady) }
                Button("연결 종료") { rtc.disconnect() }
            }
        }.padding().textFieldStyle(.roundedBorder).onDisappear { rtc.disconnect() }
    }
}
