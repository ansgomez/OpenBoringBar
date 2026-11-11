import Foundation

/// Picks the menu item that opens a new window from an app's menu items.
///
/// Order of preference: an item titled exactly "New Window"; an item titled
/// "New … Window" (e.g. "New Finder Window"), but not a private-browsing one;
/// the item with the shortcut Command-N. The last rule works in any language;
/// the title rules only match English menus.
enum NewWindowMenuItemRule {
    private static let commandOnlyModifiers = 0
    private static let excludedWords: Set<String> = ["private", "incognito", "inprivate", "guest", "tab"]

    /// Index into `items` of the item to press, or `nil` when none fits.
    static func bestIndex(in items: [AppMenuItemInfo]) -> Int? {
        let candidates = items.enumerated().filter { $0.element.isEnabled && !$0.element.hasSubmenu }

        if let exact = candidates.first(where: { words(of: $0.element.title) == ["new", "window"] }) {
            return exact.offset
        }

        let named = candidates.filter { isNewWindowTitle($0.element.title) }
        if let match = named.first(where: { isCommandN($0.element) }) ?? named.first {
            return match.offset
        }

        return candidates.first(where: { isCommandN($0.element) })?.offset
    }

    /// Whether a submenu with this title is worth reading (e.g. Terminal's
    /// "New Window" submenu of profiles). Other submenus can be very long.
    static func shouldReadSubmenu(titled title: String) -> Bool {
        words(of: title).first == "new"
    }

    private static func isNewWindowTitle(_ title: String) -> Bool {
        let titleWords = words(of: title)
        return titleWords.first == "new"
            && titleWords.contains("window")
            && excludedWords.isDisjoint(with: titleWords)
    }

    private static func isCommandN(_ item: AppMenuItemInfo) -> Bool {
        item.commandCharacter?.uppercased() == "N" && item.commandModifiers == commandOnlyModifiers
    }

    private static func words(of title: String) -> [String] {
        title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
