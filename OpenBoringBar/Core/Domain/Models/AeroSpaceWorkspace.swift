/// One AeroSpace workspace.
struct AeroSpaceWorkspace: Hashable {
    let name: String
    /// 1-based index into `NSScreen.screens` of the monitor showing it, if known.
    let screenNumber: Int?
    /// Shown on its monitor right now.
    let isVisible: Bool
    /// The workspace with keyboard focus.
    let isFocused: Bool
}
