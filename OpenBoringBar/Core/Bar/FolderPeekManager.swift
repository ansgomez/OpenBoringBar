import Combine
import Foundation

/// Owns the list of peeked folders and the Show Folders setting.
final class FolderPeekManager: ObservableObject {
    private static let isEnabledDefaultsKey = "OpenBoringBar.showFolders"

    @Published private(set) var folders: [PeekFolder]
    @Published private(set) var isEnabled: Bool

    private let storage: PeekFolderStoring
    private let defaults: UserDefaults

    /// First launch: import Folder Peek's folders, or fall back to Downloads.
    init(
        storage: PeekFolderStoring = PeekFolderStorageProvider(),
        defaults: UserDefaults = .standard,
        initialFolders: () -> [PeekFolder] = FolderPeekManager.defaultFolders
    ) {
        self.storage = storage
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Self.isEnabledDefaultsKey) as? Bool ?? true
        if let saved = storage.load() {
            self.folders = saved
        } else {
            let folders = initialFolders()
            self.folders = folders
            storage.save(folders)
        }
    }

    /// Folders shown as widgets on the bar.
    var barFolders: [PeekFolder] { folders.filter { $0.isInStartMenu != true } }
    /// Folders listed in the Start menu.
    var startMenuFolders: [PeekFolder] { folders.filter { $0.isInStartMenu == true } }

    static func defaultFolders() -> [PeekFolder] {
        let imported = FolderPeekImporter.importFolders()
        if !imported.isEmpty {
            return imported
        }
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        return [PeekFolder(path: downloads.path, sortOrder: .dateAdded, keepsFoldersOnTop: false)]
    }

    func setEnabled(_ isEnabled: Bool) {
        guard self.isEnabled != isEnabled else {
            return
        }
        self.isEnabled = isEnabled
        defaults.set(isEnabled, forKey: Self.isEnabledDefaultsKey)
    }

    /// Adds a folder (name order, folders first) unless it is already listed.
    func add(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard !folders.contains(where: { $0.path == path }) else {
            return
        }
        folders.append(PeekFolder(path: path, sortOrder: .name, keepsFoldersOnTop: true))
        storage.save(folders)
    }

    func remove(_ folder: PeekFolder) {
        folders.removeAll { $0.id == folder.id }
        storage.save(folders)
    }

    func setSortOrder(_ order: FolderSortOrder, for folder: PeekFolder) {
        update(folder) { $0.sortOrder = order }
    }

    /// Moves a folder between the bar and the Start menu.
    func setInStartMenu(_ isInStartMenu: Bool, for folder: PeekFolder) {
        update(folder) { $0.isInStartMenu = isInStartMenu ? true : nil }
    }

    /// `nil` restores the Finder icon.
    func setCustomIcon(path: String?, for folder: PeekFolder) {
        update(folder) { $0.customIconPath = path }
    }

    /// Sets an image badge (clears any symbol badge).
    func setBadgeImage(path: String, for folder: PeekFolder) {
        update(folder) {
            $0.badgeImagePath = path
            $0.badgeSymbol = nil
        }
    }

    /// Sets a symbol badge (clears any image badge). A preset symbol also
    /// takes the preset's default color.
    func setBadgeSymbol(_ symbol: String, for folder: PeekFolder) {
        update(folder) {
            $0.badgeSymbol = symbol
            $0.badgeImagePath = nil
            $0.badgeColor = FolderBadgePreset(rawValue: symbol)?.defaultColor
        }
    }

    func setBadgeColor(_ color: FolderBadgeColor, for folder: PeekFolder) {
        update(folder) { $0.badgeColor = color }
    }

    func removeBadge(for folder: PeekFolder) {
        update(folder) {
            $0.badgeSymbol = nil
            $0.badgeImagePath = nil
            $0.badgeColor = nil
        }
    }

    private func update(_ folder: PeekFolder, _ change: (inout PeekFolder) -> Void) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }
        change(&folders[index])
        storage.save(folders)
    }
}
