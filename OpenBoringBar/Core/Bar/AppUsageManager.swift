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
    /// Apps the user added to the Start menu, in the order added.
    private(set) var favorites: [String]
    /// `true` until something was saved: the list can then be seeded once.
    private(set) var needsSeed: Bool

    init(storage: AppUsageStoring, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        let snapshot = storage.load()
        self.records = snapshot?.records ?? [:]
        self.hidden = Set(snapshot?.hiddenBundleIdentifiers ?? [])
        self.favorites = snapshot?.favoriteBundleIdentifiers ?? []
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

    func isFavorite(bundleIdentifier: String) -> Bool {
        favorites.contains(bundleIdentifier)
    }

    /// Also undoes an earlier removal from "Frequently Used": adding an app
    /// to the Start menu is how a removed app comes back.
    func addFavorite(bundleIdentifier: String) {
        guard !favorites.contains(bundleIdentifier) else {
            return
        }
        hidden.remove(bundleIdentifier)
        favorites.append(bundleIdentifier)
        save()
    }

    func removeFavorite(bundleIdentifier: String) {
        guard favorites.contains(bundleIdentifier) else {
            return
        }
        favorites.removeAll { $0 == bundleIdentifier }
        save()
    }

    func hide(bundleIdentifier: String) {
        hidden.insert(bundleIdentifier)
        save()
    }

    /// The `limit` most used apps plus the always-included ones (the pins),
    /// without the hidden ones and the favorites (listed on their own).
    func frequentApplications(
        among installed: [LaunchableApplicationItem],
        alwaysIncludedBundleIdentifiers: Set<String>,
        limit: Int
    ) -> [LaunchableApplicationItem] {
        AppUsageCalculator.frequentApplications(
            among: installed,
            records: records,
            excludedBundleIdentifiers: hidden.union(favorites),
            alwaysIncludedBundleIdentifiers: alwaysIncludedBundleIdentifiers,
            limit: limit,
            now: now()
        )
    }

    private func save() {
        needsSeed = false
        storage.save(
            AppUsageSnapshot(
                records: records,
                hiddenBundleIdentifiers: hidden.isEmpty ? nil : hidden.sorted(),
                favoriteBundleIdentifiers: favorites.isEmpty ? nil : favorites
            )
        )
    }
}
