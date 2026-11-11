/// Saved app usage, keyed by bundle identifier.
struct AppUsageSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = AppUsageSnapshot.currentVersion
    var records: [String: AppUsageRecord]
    /// Apps the user removed from "Frequently Used". Optional: older saves
    /// do not have it.
    var hiddenBundleIdentifiers: [String]?
    /// Apps the user added to the Start menu's "Favorites", in the order
    /// added. Optional: older saves do not have it.
    var favoriteBundleIdentifiers: [String]?
}
