import Foundation

/// A pin ready to draw on one bar. Not saved.
struct PinnedAppItem: Identifiable, Hashable {
    let pin: PinnedApp
    let resolvedURL: URL
    let name: String
    let isRunning: Bool

    var id: String { pin.bundleIdentifier ?? pin.bundleURL.path }
}
