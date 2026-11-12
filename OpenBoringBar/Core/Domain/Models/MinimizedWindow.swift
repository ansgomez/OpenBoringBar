import CoreGraphics

/// A window the user minimized to the Dock. AeroSpace drops these from its
/// workspaces, so the bar tracks them itself.
struct MinimizedWindow: Identifiable, Hashable {
    let id: CGWindowID
    let processID: pid_t
    let appName: String
    let title: String
    /// Last frame before minimizing, used to pick a screen.
    let frame: CGRect
    var bundleIdentifier: String? = nil
}
