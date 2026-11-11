/// Color of a symbol badge. Stored by name; mapped to AppKit colors in
/// `FolderBadgeColor+AppKit.swift`.
enum FolderBadgeColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, teal, blue, purple, pink, brown, gray

    var menuTitle: String { rawValue.capitalized }
}
