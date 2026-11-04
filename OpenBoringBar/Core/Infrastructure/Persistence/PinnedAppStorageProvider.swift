import Foundation

protocol PinnedAppStoring {
    func load() -> PinnedAppsSnapshot?
    func save(_ snapshot: PinnedAppsSnapshot)
}

/// Saves pin state as JSON in UserDefaults.
final class PinnedAppStorageProvider: PinnedAppStoring {
    static let defaultsKey = "OpenBoringBar.pinnedApps"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns `nil` when nothing is saved, the data does not decode, or the
    /// saved version is unknown. Bad data is logged and replaced on next save.
    func load() -> PinnedAppsSnapshot? {
        guard let data = defaults.data(forKey: Self.defaultsKey) else {
            return nil
        }

        guard let snapshot = try? JSONDecoder().decode(PinnedAppsSnapshot.self, from: data) else {
            NSLog("OpenBoringBar: saved pinned apps could not be read; starting empty")
            return nil
        }

        guard snapshot.version == PinnedAppsSnapshot.currentVersion else {
            NSLog("OpenBoringBar: unknown pinned apps version \(snapshot.version); starting empty")
            return nil
        }

        return snapshot
    }

    func save(_ snapshot: PinnedAppsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            NSLog("OpenBoringBar: pinned apps could not be encoded")
            return
        }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
