import Foundation

/// A pin ready to draw on one bar. Not saved.
struct PinnedAppItem: Identifiable, Hashable {
    let pin: PinnedApp
    let resolvedURL: URL
    let name: String
    /// Process of the matching running app, `nil` when not running.
    let processID: pid_t?

    var isRunning: Bool { processID != nil }

    var id: String { pin.bundleIdentifier ?? pin.bundleURL.path }
}
