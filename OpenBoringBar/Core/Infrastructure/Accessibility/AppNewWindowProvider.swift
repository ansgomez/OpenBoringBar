import ApplicationServices
import Foundation

/// Opens a new window in another app by pressing its own "New Window" menu
/// item through Accessibility. The app is not activated, so a tiling window
/// manager does not jump to the workspace of the app's existing windows.
/// Blocks on the target app; call off the main thread.
enum AppNewWindowProvider {
    /// Menus read after the Apple menu: the app menu, File (or Shell), Edit.
    /// Later menus (History, Bookmarks) can hold thousands of items.
    private static let scannedMenuCount = 3
    private static let pressAction = "AXPress" as CFString

    /// `false` when the app has no usable menu item or cannot be reached.
    static func openNewWindow(processID: pid_t) -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }
        let appElement = AXUIElementCreateApplication(processID)
        guard let menuBar = AXElementInspector.elementAttributeValue(of: AXAttributeName.menuBar, from: appElement),
              let menuBarItems = AXElementInspector.children(from: menuBar) else {
            return false
        }

        var elements: [AXUIElement] = []
        var infos: [AppMenuItemInfo] = []
        for menuBarItem in menuBarItems.dropFirst().prefix(scannedMenuCount) {
            collectItems(under: menuBarItem, readsSubmenus: true, elements: &elements, infos: &infos)
        }

        guard let index = NewWindowMenuItemRule.bestIndex(in: infos) else {
            return false
        }
        // An app that takes long to act on the item reports `cannotComplete`
        // although the press went through.
        let result = AXUIElementPerformAction(elements[index], pressAction)
        return result == .success || result == .cannotComplete
    }

    /// Appends the items of the menu that `parent` (a menu bar item or a
    /// menu item with a submenu) opens.
    private static func collectItems(
        under parent: AXUIElement,
        readsSubmenus: Bool,
        elements: inout [AXUIElement],
        infos: inout [AppMenuItemInfo]
    ) {
        guard let menu = AXElementInspector.children(from: parent)?.first,
              let items = AXElementInspector.children(from: menu) else {
            return
        }
        for item in items {
            let title = AXElementInspector.stringAttributeValue(of: AXAttributeName.title, from: item) ?? ""
            guard !title.isEmpty else {
                continue // separator
            }
            let hasSubmenu = !(AXElementInspector.children(from: item) ?? []).isEmpty
            elements.append(item)
            infos.append(AppMenuItemInfo(
                title: title,
                commandCharacter: AXElementInspector.stringAttributeValue(
                    of: AXAttributeName.menuItemCommandCharacter,
                    from: item
                ),
                commandModifiers: AXElementInspector.intAttributeValue(
                    of: AXAttributeName.menuItemCommandModifiers,
                    from: item
                ),
                isEnabled: AXElementInspector.boolAttributeValue(of: AXAttributeName.enabled, from: item) ?? true,
                hasSubmenu: hasSubmenu
            ))
            if hasSubmenu, readsSubmenus, NewWindowMenuItemRule.shouldReadSubmenu(titled: title) {
                collectItems(under: item, readsSubmenus: false, elements: &elements, infos: &infos)
            }
        }
    }
}
