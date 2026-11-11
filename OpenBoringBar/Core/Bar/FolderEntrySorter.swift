import Foundation

/// Orders folder entries like Finder / Folder Peek.
enum FolderEntrySorter {
    static func sorted(
        _ entries: [FolderEntry],
        by order: FolderSortOrder,
        keepingFoldersOnTop: Bool
    ) -> [FolderEntry] {
        entries.sorted { lhs, rhs in
            if keepingFoldersOnTop, lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            switch order {
            case .name:
                break
            case .dateAdded:
                if let result = newerFirst(lhs.dateAdded ?? lhs.dateModified, rhs.dateAdded ?? rhs.dateModified) {
                    return result
                }
            case .dateModified:
                if let result = newerFirst(lhs.dateModified, rhs.dateModified) {
                    return result
                }
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// `nil` when equal, so callers fall back to name order.
    private static func newerFirst(_ lhs: Date?, _ rhs: Date?) -> Bool? {
        switch (lhs, rhs) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return nil
        }
    }
}
