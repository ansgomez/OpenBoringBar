import AppKit

/// Builds the menu a folder widget opens: the folder's items, sorted, with
/// subfolders as submenus filled when they open. Click opens an item;
/// Option-click reveals it in Finder. Keep the builder alive while its menu
/// is open (it owns the submenu delegates).
final class FolderPeekMenuBuilder {
    /// Items past this are reached through "Show All in Finder".
    static let maxEntriesPerMenu = 60
    private static let iconSize = NSSize(width: 16, height: 16)

    private var submenuDelegates: [FolderSubmenuDelegate] = []

    func menu(for folder: PeekFolder) -> NSMenu {
        let menu = NSMenu(title: folder.name)
        menu.autoenablesItems = false
        fill(menu, folderURL: folder.url, title: folder.name, sortOrder: folder.sortOrder, foldersOnTop: folder.keepsFoldersOnTop)
        let headerIcon = FolderIconRenderer.shared.icon(for: folder).copy() as? NSImage
        headerIcon?.size = Self.iconSize
        menu.items.first?.image = headerIcon
        return menu
    }

    fileprivate func fill(
        _ menu: NSMenu,
        folderURL: URL,
        title: String,
        sortOrder: FolderSortOrder,
        foldersOnTop: Bool
    ) {
        menu.removeAllItems()

        let header = ClosureMenuItem(title: "Open “\(title)” in Finder") {
            NSWorkspace.shared.open(folderURL)
        }
        header.image = Self.icon(for: folderURL)
        menu.addItem(header)
        menu.addItem(.separator())

        let entries = FolderEntrySorter.sorted(
            FolderContentsProvider.entries(of: folderURL),
            by: sortOrder,
            keepingFoldersOnTop: foldersOnTop
        )

        if entries.isEmpty {
            let empty = NSMenuItem(title: "Empty Folder", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for entry in entries.prefix(Self.maxEntriesPerMenu) {
            menu.addItem(item(for: entry, sortOrder: sortOrder, foldersOnTop: foldersOnTop))
        }

        if entries.count > Self.maxEntriesPerMenu {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(title: "Show All \(entries.count) Items in Finder…") {
                NSWorkspace.shared.open(folderURL)
            })
        }
    }

    private func item(for entry: FolderEntry, sortOrder: FolderSortOrder, foldersOnTop: Bool) -> NSMenuItem {
        let url = entry.url
        let item = ClosureMenuItem(title: entry.name) {
            if NSEvent.modifierFlags.contains(.option) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        item.image = Self.icon(for: url)
        item.toolTip = url.path

        if entry.isDirectory {
            let submenu = NSMenu(title: entry.name)
            submenu.autoenablesItems = false
            let delegate = FolderSubmenuDelegate(
                builder: self,
                folderURL: url,
                title: entry.name,
                sortOrder: sortOrder,
                foldersOnTop: foldersOnTop
            )
            submenuDelegates.append(delegate)
            submenu.delegate = delegate
            // Placeholder so the submenu arrow shows before it is filled.
            submenu.addItem(NSMenuItem(title: "…", action: nil, keyEquivalent: ""))
            item.submenu = submenu
        }
        return item
    }

    private static func icon(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = iconSize
        return icon
    }
}

/// Fills a subfolder's submenu the first time it opens.
private final class FolderSubmenuDelegate: NSObject, NSMenuDelegate {
    private weak var builder: FolderPeekMenuBuilder?
    private let folderURL: URL
    private let title: String
    private let sortOrder: FolderSortOrder
    private let foldersOnTop: Bool
    private var isFilled = false

    init(builder: FolderPeekMenuBuilder, folderURL: URL, title: String, sortOrder: FolderSortOrder, foldersOnTop: Bool) {
        self.builder = builder
        self.folderURL = folderURL
        self.title = title
        self.sortOrder = sortOrder
        self.foldersOnTop = foldersOnTop
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard !isFilled, let builder else {
            return
        }
        isFilled = true
        builder.fill(menu, folderURL: folderURL, title: title, sortOrder: sortOrder, foldersOnTop: foldersOnTop)
    }
}
