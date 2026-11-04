import Foundation

/// A pinned app as saved on disk. Matched by bundle identifier first, so a
/// pin survives the app being moved; `bundleURL` is the last known location.
struct PinnedApp: Codable, Hashable {
    var bundleIdentifier: String?
    var bundleURL: URL
}
