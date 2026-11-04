import CoreGraphics

/// Snapshot of AeroSpace's workspaces and windows.
struct AeroSpaceState: Equatable {
    /// In AeroSpace's order.
    var workspaces: [AeroSpaceWorkspace]
    var windows: [AeroSpaceWindow]
    /// The window with keyboard focus, if any.
    var focusedWindowID: CGWindowID? = nil

    static let empty = AeroSpaceState(workspaces: [], windows: [])

    var workspaceByWindowID: [CGWindowID: String] {
        Dictionary(windows.map { ($0.id, $0.workspace) }, uniquingKeysWith: { first, _ in first })
    }

    var focusedWorkspace: String? {
        workspaces.first(where: \.isFocused)?.name
    }
}
