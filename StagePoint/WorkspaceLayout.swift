import SwiftUI

/// Use the available window width, not the physical screen, so keyboard changes
/// do not switch layouts and smaller windows retain the compact controls.
struct WorkspaceLayout {
    let width: CGFloat
    var isExpanded: Bool { width >= 1_000 }
    var panelWidth: CGFloat { isExpanded ? min(360, max(300, width * 0.29)) : 245 }
    var editorPanelWidth: CGFloat { isExpanded ? panelWidth : 255 }
    var spacing: CGFloat { isExpanded ? 20 : 12 }
    var padding: CGFloat { isExpanded ? 20 : 12 }
    var cornerDiameter: CGFloat { isExpanded ? 44 : 34 }
    var cornerTouchSize: CGFloat { isExpanded ? 64 : 52 }
    var minimapHeight: CGFloat { isExpanded ? 190 : 110 }
}

private struct WorkspaceLayoutKey: EnvironmentKey {
    static let defaultValue = WorkspaceLayout(width: 800)
}

extension EnvironmentValues {
    var workspaceLayout: WorkspaceLayout {
        get { self[WorkspaceLayoutKey.self] }
        set { self[WorkspaceLayoutKey.self] = newValue }
    }
}
