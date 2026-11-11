import Foundation

/// One visible item inside a peeked folder.
struct FolderEntry: Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let dateAdded: Date?
    let dateModified: Date?
}
