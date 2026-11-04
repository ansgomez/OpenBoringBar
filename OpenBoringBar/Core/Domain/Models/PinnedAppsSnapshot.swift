import Foundation

/// Saved form of all pin state.
struct PinnedAppsSnapshot: Codable, Equatable {
    static let currentVersion = 1
    static let empty = PinnedAppsSnapshot(
        version: currentVersion,
        mode: .allDisplays,
        sharedPins: [],
        perDisplayPins: [:]
    )

    var version: Int
    var mode: PinDisplayMode
    /// Used by `allDisplays` and `mainDisplayOnly`.
    var sharedPins: [PinnedApp]
    /// Used by `perDisplay`, keyed by display UUID string. Never pruned, so a
    /// reconnected monitor gets its pins back.
    var perDisplayPins: [String: [PinnedApp]]
}
