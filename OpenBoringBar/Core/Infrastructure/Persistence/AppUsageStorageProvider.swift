import Foundation

protocol AppUsageStoring {
    func load() -> AppUsageSnapshot?
    func save(_ snapshot: AppUsageSnapshot)
}

/// Saves app usage as JSON in UserDefaults.
final class AppUsageStorageProvider: AppUsageStoring {
    static let defaultsKey = "OpenBoringBar.appUsage"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// `nil` when nothing is saved or the data cannot be read.
    func load() -> AppUsageSnapshot? {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let snapshot = try? JSONDecoder().decode(AppUsageSnapshot.self, from: data),
              snapshot.version == AppUsageSnapshot.currentVersion else {
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: AppUsageSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
