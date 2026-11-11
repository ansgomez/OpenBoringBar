import Foundation

/// The math behind the Start menu's "Frequently Used" list.
enum AppUsageCalculator {
    /// A use counts half as much after this long, so the list follows habits.
    static let halfLife: TimeInterval = 30 * 24 * 3600
    /// Spotlight data older than this is not used as a seed.
    static let seedRecency: TimeInterval = 30 * 24 * 3600

    static func score(of record: AppUsageRecord, at now: Date) -> Double {
        let elapsed = max(0, now.timeIntervalSince(record.lastUsed))
        return record.score * pow(0.5, elapsed / halfLife)
    }

    /// The record after one more use at `now`.
    static func recordingUse(on record: AppUsageRecord?, at now: Date) -> AppUsageRecord {
        AppUsageRecord(score: (record.map { score(of: $0, at: now) } ?? 0) + 1, lastUsed: now)
    }

    /// Starting record from Spotlight's lifetime use count. The count is put
    /// on a log scale (10 000 uses become about 13), so uses the bar counts
    /// itself soon outweigh it. `nil` for apps not used recently.
    static func seedRecord(from seed: AppUsageSeed, now: Date) -> AppUsageRecord? {
        guard seed.useCount > 0, now.timeIntervalSince(seed.lastUsed) <= seedRecency else {
            return nil
        }
        return AppUsageRecord(score: log2(Double(seed.useCount) + 1), lastUsed: seed.lastUsed)
    }

    /// The `limit` most used installed apps, plus every app in
    /// `alwaysIncludedBundleIdentifiers` (the pins) that did not make the cut,
    /// best first. Other apps never used are left out, and so is everything in
    /// `excludedBundleIdentifiers` (apps the user removed from the list).
    /// Equal scores keep the order of `installed`.
    static func frequentApplications(
        among installed: [LaunchableApplicationItem],
        records: [String: AppUsageRecord],
        excludedBundleIdentifiers: Set<String>,
        alwaysIncludedBundleIdentifiers: Set<String> = [],
        limit: Int,
        now: Date
    ) -> [LaunchableApplicationItem] {
        var seen = Set<String>()
        let scored: [(offset: Int, app: LaunchableApplicationItem, score: Double)] = installed.enumerated()
            .compactMap { offset, app in
                guard let identifier = app.bundleIdentifier,
                      !excludedBundleIdentifiers.contains(identifier),
                      records[identifier] != nil || alwaysIncludedBundleIdentifiers.contains(identifier),
                      seen.insert(identifier).inserted else {
                    return nil
                }
                return (offset, app, records[identifier].map { score(of: $0, at: now) } ?? 0)
            }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
            .enumerated()
            .filter { rank, entry in
                rank < limit || alwaysIncludedBundleIdentifiers.contains(entry.app.bundleIdentifier ?? "")
            }
            .map(\.element.app)
    }
}
