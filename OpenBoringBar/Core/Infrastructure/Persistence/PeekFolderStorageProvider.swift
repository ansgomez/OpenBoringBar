import Foundation

protocol PeekFolderStoring {
    /// `nil` when nothing was ever saved (first launch) or the data is unreadable.
    func load() -> [PeekFolder]?
    func save(_ folders: [PeekFolder])
}

final class PeekFolderStorageProvider: PeekFolderStoring {
    static let defaultsKey = "OpenBoringBar.peekFolders"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [PeekFolder]? {
        guard let data = defaults.data(forKey: Self.defaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode([PeekFolder].self, from: data)
    }

    func save(_ folders: [PeekFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else {
            return
        }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
