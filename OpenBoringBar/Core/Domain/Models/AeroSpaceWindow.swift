import CoreGraphics

/// One window as AeroSpace reports it. `id` equals the CoreGraphics window number.
struct AeroSpaceWindow: Identifiable, Hashable {
    let id: CGWindowID
    let workspace: String
    let processID: pid_t?
    let bundleIdentifier: String?
    let appName: String
    /// AeroSpace layout of the window's parent, e.g. `h_tiles` or `floating`.
    let layout: String
    let title: String

    var isFloating: Bool { layout == "floating" }
}
