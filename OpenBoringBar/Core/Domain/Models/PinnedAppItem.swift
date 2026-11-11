import Foundation

/// An icon of the pin strip on one bar: a pin, or (`isPinned` false) a
/// running app that is not pinned, shown after the pins like in the Dock.
/// Not saved.
struct PinnedAppItem: Identifiable, Hashable {
    let pin: PinnedApp
    let resolvedURL: URL
    let name: String
    /// Process of the matching running app, `nil` when not running.
    let processID: pid_t?
    var isPinned: Bool = true

    var isRunning: Bool { processID != nil }

    var id: String { pin.bundleIdentifier ?? pin.bundleURL.path }
}
