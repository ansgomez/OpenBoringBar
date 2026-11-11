import AppKit

/// Builds the Start menu: the most used apps and the pinned ones, every
/// installed app (submenu), the Applications folder to browse (submenu), and
/// the workspace layout scripts.
/// Click opens an app; Option-click reveals it in Finder. Right-click (or
/// Control-click) a "Frequently Used" app for a menu that can remove it from
/// that list. Keep the builder
/// alive while its menu is open (it owns the submenu delegates).
final class StartMenuBuilder {
    private static let iconSize = NSSize(width: 18, height: 18)
    private static let applicationsFolderPath = "/Applications"

    private let folderMenuBuilder = FolderPeekMenuBuilder()
    private var allApplicationsDelegate: AllApplicationsMenuDelegate?

    func menu(
        frequent: [LaunchableApplicationItem],
        hiddenFrequentCount: Int,
        all: [LaunchableApplicationItem],
        layouts: [WorkspaceLayoutScript]?,
        onOpen: @escaping (URL) -> Void,
        onRunLayout: @escaping (WorkspaceLayoutScript) -> Void,
        onHideFrequent: @escaping (String) -> Void,
        onRestoreHiddenFrequent: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu(title: "Start")
        menu.autoenablesItems = false

        menu.addItem(.sectionHeader(title: "Frequently Used"))
        if frequent.isEmpty {
            let empty = NSMenuItem(title: "No apps used yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for app in frequent {
            menu.addItem(Self.item(for: app, onOpen: onOpen, onHide: onHideFrequent))
        }
        if hiddenFrequentCount > 0 {
            menu.addItem(
                ClosureMenuItem(title: "Restore Removed Apps (\(hiddenFrequentCount))", handler: onRestoreHiddenFrequent)
            )
        }
        menu.addItem(.separator())

        let allItem = NSMenuItem(title: "All Applications", action: nil, keyEquivalent: "")
        allItem.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        let allMenu = NSMenu(title: allItem.title)
        allMenu.autoenablesItems = false
        // Filled when it opens: loading every app icon takes a moment.
        let delegate = AllApplicationsMenuDelegate(applications: all, onOpen: onOpen)
        allApplicationsDelegate = delegate
        allMenu.delegate = delegate
        allMenu.addItem(NSMenuItem(title: "…", action: nil, keyEquivalent: ""))
        allItem.submenu = allMenu
        menu.addItem(allItem)

        let folder = PeekFolder(path: Self.applicationsFolderPath, sortOrder: .name, keepsFoldersOnTop: false)
        let folderItem = NSMenuItem(title: "Applications Folder", action: nil, keyEquivalent: "")
        folderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        folderItem.submenu = folderMenuBuilder.menu(for: folder)
        menu.addItem(folderItem)

        if let layouts {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "Workspace Layouts"))
            for layout in layouts {
                let item = ClosureMenuItem(title: layout.name) { onRunLayout(layout) }
                item.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
                item.toolTip = layout.url.path
                menu.addItem(item)
            }
            let openFolder = ClosureMenuItem(title: "Open Layouts Folder") {
                NSWorkspace.shared.open(WorkspaceLayoutProvider.ensureDirectory())
            }
            openFolder.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: nil)
            menu.addItem(openFolder)
        }

        return menu
    }

    fileprivate static func item(
        for app: LaunchableApplicationItem,
        onOpen: @escaping (URL) -> Void,
        onHide: ((String) -> Void)? = nil
    ) -> NSMenuItem {
        let url = app.bundleURL
        let item = ClosureMenuItem(title: app.name) {
            if let onHide, let identifier = app.bundleIdentifier, isSecondaryClick(NSApp.currentEvent) {
                // The Start menu has closed by now; show the item's own menu.
                DispatchQueue.main.async {
                    itemMenu(for: app, identifier: identifier, onOpen: onOpen, onHide: onHide)
                        .popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
                }
            } else if NSEvent.modifierFlags.contains(.option) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                onOpen(url)
            }
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = iconSize
        item.image = icon
        item.toolTip = url.path
        return item
    }

    /// Right mouse button, or Control-click.
    private static func isSecondaryClick(_ event: NSEvent?) -> Bool {
        guard let event else {
            return false
        }
        switch event.type {
        case .rightMouseUp, .rightMouseDown:
            return true
        case .leftMouseUp, .leftMouseDown:
            return event.modifierFlags.contains(.control)
        default:
            return false
        }
    }

    private static func itemMenu(
        for app: LaunchableApplicationItem,
        identifier: String,
        onOpen: @escaping (URL) -> Void,
        onHide: @escaping (String) -> Void
    ) -> NSMenu {
        let url = app.bundleURL
        let menu = NSMenu(title: app.name)
        menu.autoenablesItems = false
        menu.addItem(ClosureMenuItem(title: "Open \(app.name)") { onOpen(url) })
        menu.addItem(ClosureMenuItem(title: "Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Remove from Frequently Used") { onHide(identifier) })
        return menu
    }
}

/// Fills the "All Applications" submenu the first time it opens.
private final class AllApplicationsMenuDelegate: NSObject, NSMenuDelegate {
    private let applications: [LaunchableApplicationItem]
    private let onOpen: (URL) -> Void
    private var isFilled = false

    init(applications: [LaunchableApplicationItem], onOpen: @escaping (URL) -> Void) {
        self.applications = applications
        self.onOpen = onOpen
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard !isFilled else {
            return
        }
        isFilled = true
        menu.removeAllItems()
        for app in applications {
            menu.addItem(StartMenuBuilder.item(for: app, onOpen: onOpen))
        }
    }
}
