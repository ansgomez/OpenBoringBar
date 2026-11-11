/// How a peeked folder's entries are ordered.
enum FolderSortOrder: String, Codable, CaseIterable {
    case name
    /// Newest first.
    case dateAdded
    /// Newest first.
    case dateModified
}

extension FolderSortOrder {
    var menuTitle: String {
        switch self {
        case .name: return "Name"
        case .dateAdded: return "Date Added"
        case .dateModified: return "Date Modified"
        }
    }
}
