import Foundation

/// Reads the folder list of the Folder Peek app (sindresorhus), read-only, so
/// the bar can start with the same folders.
enum FolderPeekImporter {
    static let preferencesURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers/com.sindresorhus.Folder-Peek/Data/Library/Preferences/com.sindresorhus.Folder-Peek.plist")

    /// Folders from Folder Peek's preferences, in its order; `[]` when Folder
    /// Peek is not installed or its data cannot be read.
    static func importFolders(from url: URL = preferencesURL) -> [PeekFolder] {
        guard let dictionary = NSDictionary(contentsOf: url) as? [String: Any],
              let entries = dictionary["folders"] as? [String] else {
            return []
        }
        return folders(fromEntries: entries, resolveBookmark: resolvePath(ofBookmark:))
    }

    /// Each entry is a JSON object with a base64 `urlBookmark`, `sortOrder`
    /// and `keepFoldersOnTop`. Entries that cannot be resolved are skipped.
    static func folders(
        fromEntries entries: [String],
        resolveBookmark: (Data) -> String?
    ) -> [PeekFolder] {
        entries.compactMap { entry in
            guard let data = entry.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (object["isVisible"] as? Bool) ?? true,
                  let bookmarkString = object["urlBookmark"] as? String,
                  let bookmark = Data(base64Encoded: bookmarkString),
                  let path = resolveBookmark(bookmark) else {
                return nil
            }
            return PeekFolder(
                path: path,
                sortOrder: sortOrder(fromFolderPeekValue: object["sortOrder"] as? String),
                keepsFoldersOnTop: (object["keepFoldersOnTop"] as? Bool) ?? true
            )
        }
    }

    static func sortOrder(fromFolderPeekValue value: String?) -> FolderSortOrder {
        switch value {
        case "dateAdded": return .dateAdded
        case "dateModified", "dateLastModified": return .dateModified
        default: return .name
        }
    }

    private static func resolvePath(ofBookmark bookmark: Data) -> String? {
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return url?.path
    }
}
