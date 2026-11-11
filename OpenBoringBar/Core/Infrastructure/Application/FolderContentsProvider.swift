import Foundation

/// Lists the visible items of a folder (no hidden files, no package contents).
enum FolderContentsProvider {
    private static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .addedToDirectoryDateKey, .contentModificationDateKey, .localizedNameKey
    ]

    static func entries(of folderURL: URL) -> [FolderEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            // Apps and other packages open like files.
            let isDirectory = (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
            return FolderEntry(
                url: url,
                name: values?.localizedName ?? url.lastPathComponent,
                isDirectory: isDirectory,
                dateAdded: values?.addedToDirectoryDate,
                dateModified: values?.contentModificationDate
            )
        }
    }
}
