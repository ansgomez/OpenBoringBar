import CoreGraphics

/// Which tiling-window-manager workspace each window belongs to.
struct WindowWorkspaceSnapshot: Equatable {
    var workspaceByWindowID: [CGWindowID: String]
    var focusedWorkspace: String?

    static let empty = WindowWorkspaceSnapshot(workspaceByWindowID: [:], focusedWorkspace: nil)
}
