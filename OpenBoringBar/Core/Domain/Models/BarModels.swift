import CoreGraphics

struct RunningAppItem: Identifiable, Hashable {
    let processID: pid_t
    let name: String
    let isFrontmost: Bool
    let notificationBadgeCount: Int
    /// Set when the pill stands for one window (AeroSpace "pills follow
    /// workspace" mode) instead of the whole app.
    var windowID: CGWindowID? = nil
    /// The window is minimized to the Dock; the pill is drawn dimmed and a
    /// click restores the window.
    var isMinimized: Bool = false

    var id: String {
        windowID.map { "window-\($0)" } ?? "app-\(processID)"
    }
}

struct DisplayState: Identifiable {
    let id: CGDirectDisplayID
    let frame: CGRect
    var apps: [RunningAppItem]
    /// Filled by `BarManager` after the display state is built.
    var displayUUID: String? = nil
    var isMainDisplay: Bool = false
    var canEditPins: Bool = true
    var pinnedApps: [PinnedAppItem] = []
    /// Running apps that are not pinned on this bar, in launch order.
    var runningUnpinnedApps: [PinnedAppItem] = []
    /// AeroSpace workspaces on this display; empty when the row is hidden.
    var workspaceGroups: [WorkspaceGroup] = []
    /// Minimized windows of this display, drawn as the "–" group after the
    /// workspaces. Empty when the workspace groups are hidden.
    var minimizedWindows: [MinimizedWindow] = []
    /// Workspace the row's "+" target moves windows to, if one is free.
    var emptyWorkspaceTarget: String? = nil
}
