import Foundation

/// A folder shown as a widget at the right of the bar, or in the Start menu.
struct PeekFolder: Codable, Hashable, Identifiable {
    var path: String
    var sortOrder: FolderSortOrder
    var keepsFoldersOnTop: Bool
    /// Image file that replaces the folder's Finder icon.
    var customIconPath: String? = nil
    /// Image file drawn as a badge in the icon's corner. Wins over `badgeSymbol`.
    var badgeImagePath: String? = nil
    /// SF Symbol name drawn as a badge in the icon's corner.
    var badgeSymbol: String? = nil
    /// Color of a symbol badge; `nil` uses the accent color.
    var badgeColor: FolderBadgeColor? = nil
    /// `true`: listed in the Start menu, not on the bar. Optional: older
    /// saves do not have it.
    var isInStartMenu: Bool? = nil

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
    var name: String { FileManager.default.displayName(atPath: path) }
}
