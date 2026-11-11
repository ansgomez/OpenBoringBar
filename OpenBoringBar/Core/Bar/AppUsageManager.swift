import Foundation

/// Counts how often each app is brought to the front, for the Start menu's
/// "Frequently Used" list. Saved through `AppUsageStoring` under
/// `OpenBoringBar.appUsage`.
final class AppUsageManager {
    private let storage: AppUsageStoring
    private let now: () -> Date
    private var records: [String: AppUsageRecord]
    /// Apps the user removed from the list; they stay out however much used.
    private var hidden: Set<String>
    /// `true` until something was saved: the list can then be seeded once.
    private(set) var needsSeed: Bool

    init(storage: AppUsageStoring, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        let snapshot = storage.load()
        self.records = snapshot?.records ?? [:]
        self.hidden = Set(snapshot?.hiddenBundleIdentifiers ?? [])
        self.needsSeed = snapshot == nil
    }

    func recordUse(ofBundleIdentifier bundleIdentifier: String) {
        records[bundleIdentifier] = AppUsageCalculator.recordingUse(on: records[bundleIdentifier], at: now())
        save()
    }

    /// Fills in apps the bar has not counted yet; uses already counted win.
    func seed(_ seeds: [AppUsageSeed]) {
        let date = now()
        for seed in seeds where records[seed.bundleIdentifier] == nil {
            records[seed.bundleIdentifier] = AppUsageCalculator.seedRecord(from: seed, now: date)
        }
        save()
    }

    var hiddenCount: Int { hidden.count }

    func hide(bundleIdentifier: String) {
        hidden.insert(bundleIdentifier)
        save()
    }

    func unhideAll() {
        hidden.removeAll()
        save()
    }

    /// The `limit` most used apps plus the always-included ones (the pins),
    /// without the hidden ones.
    func frequentApplications(
        among installed: [LaunchableApplicationItem],
        alwaysIncludedBundleIdentifiers: Set<String>,
        limit: Int
    ) -> [LaunchableApplicationItem] {
        AppUsageCalculator.frequentApplications(
            among: installed,
            records: records,
            excludedBundleIdentifiers: hidden,
            alwaysIncludedBundleIdentifiers: alwaysIncludedBundleIdentifiers,
            limit: limit,
            now: now()
        )
    }

    private func save() {
        needsSeed = false
        storage.save(
            AppUsageSnapshot(records: records, hiddenBundleIdentifiers: hidden.isEmpty ? nil : hidden.sorted())
        )
    }
}
