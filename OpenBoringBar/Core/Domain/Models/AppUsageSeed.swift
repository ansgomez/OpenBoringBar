import Foundation

/// Usage of one app as Spotlight recorded it, used once to fill the
/// frequently-used list before the bar has counted anything itself.
struct AppUsageSeed: Equatable {
    let bundleIdentifier: String
    let useCount: Int
    let lastUsed: Date
}
