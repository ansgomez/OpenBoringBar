import CoreGraphics

/// What a click on a running pinned app does when AeroSpace is in use.
enum PinClickAction: Equatable {
    /// The app already has this window on the target workspace: focus it.
    case focusWindow(CGWindowID)
    /// Open a new window on this workspace (`nil`: workspace unknown).
    case openNewWindow(workspace: String?)
}
