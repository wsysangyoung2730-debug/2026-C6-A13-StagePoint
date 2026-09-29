import SwiftUI
import StagePointCore

@main
struct StagePointApp: App {
    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("--uitesting") && !ProcessInfo.processInfo.arguments.contains("--live-demo") {
                    ContentView().preferredColorScheme(.dark)
                } else {
                    DeviceRoleView()
                }
            }.preferredColorScheme(.light).tint(.blue)
        }
    }
}
