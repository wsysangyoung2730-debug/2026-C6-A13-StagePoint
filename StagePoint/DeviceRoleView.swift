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
    var body: some View {
        VStack(spacing: 20) {
            Text(role.title).font(.title)
            Text("실시간 연결을 준비합니다.")
            Button("역할 변경", action: onExit)
        }
    }
}
