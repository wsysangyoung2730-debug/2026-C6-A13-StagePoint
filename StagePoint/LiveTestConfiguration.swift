import Foundation
import StagePointCore

/// Explicit simulator-only transport fixture; never enabled in a device or Release build.
enum LiveTestConfiguration {
    static var role: DeviceRole? {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--transport-camera") { return .camera }
        if ProcessInfo.processInfo.arguments.contains("--transport-monitor") { return .monitor }
        #endif
        return nil
    }
}
