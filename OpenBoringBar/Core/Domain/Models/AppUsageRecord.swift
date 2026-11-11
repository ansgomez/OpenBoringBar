import Foundation

/// How much one app has been used. `score` grows by 1 per use and halves
/// every `AppUsageCalculator.halfLife`; it is valid as of `lastUsed`.
struct AppUsageRecord: Codable, Equatable {
    var score: Double
    var lastUsed: Date
}
