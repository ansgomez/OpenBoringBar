/// One item of another app's menu bar, as read through Accessibility.
struct AppMenuItemInfo: Equatable {
    let title: String
    /// Key of the shortcut, e.g. `"N"`; `nil` when the item has none.
    let commandCharacter: String?
    /// `AXMenuItemCmdModifiers` value: `0` is Command alone.
    let commandModifiers: Int?
    let isEnabled: Bool
    let hasSubmenu: Bool
}
