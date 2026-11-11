import AppKit
import SwiftUI

/// Folder widgets at the right of the bar, with a divider before them. Click
/// opens the folder's menu; right-click for Open in Finder, sort order, Move
/// to Start Menu, Remove and Add Folder…. Shows a single "+" when no folder
/// is configured, and nothing when every folder is in the Start menu.
struct FolderPeekStripView: View {
    @ObservedObject var manager: FolderPeekManager
    let rowCount: Int
    let onOpenFolderMenu: (PeekFolder) -> Void
    let onAddFolder: () -> Void
    /// Returns the chosen image file's path, or `nil` if cancelled.
    let onChooseImage: (String) -> String?

    var body: some View {
        let folders = manager.barFolders
        let rows = max(1, rowCount)
        let perRow = max(1, (folders.count + rows - 1) / rows)

        HStack(spacing: 8) {
            if manager.folders.isEmpty || !folders.isEmpty {
                Divider()
                    .padding(.vertical, 9)
            }

            if manager.folders.isEmpty {
                addButton
            } else if !folders.isEmpty {
                VStack(alignment: .leading, spacing: BarLayoutConstants.pinRowSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: BarLayoutConstants.pinSpacing) {
                            ForEach(Array(folders.dropFirst(row * perRow).prefix(perRow))) { folder in
                                FolderPeekIcon(
                                    folder: folder,
                                    onOpenMenu: onOpenFolderMenu,
                                    onAddFolder: onAddFolder,
                                    onRemove: { manager.remove(folder) },
                                    onMoveToStartMenu: { manager.setInStartMenu(true, for: folder) },
                                    onSetSortOrder: { manager.setSortOrder($0, for: folder) },
                                    onChooseIcon: {
                                        if let path = onChooseImage("Choose an icon for “\(folder.name)”") {
                                            manager.setCustomIcon(path: path, for: folder)
                                        }
                                    },
                                    onResetIcon: { manager.setCustomIcon(path: nil, for: folder) },
                                    onChooseBadgeImage: {
                                        if let path = onChooseImage("Choose a badge for “\(folder.name)”") {
                                            manager.setBadgeImage(path: path, for: folder)
                                        }
                                    },
                                    onSetBadgeSymbol: { manager.setBadgeSymbol($0, for: folder) },
                                    onSetBadgeColor: { manager.setBadgeColor($0, for: folder) },
                                    onRemoveBadge: { manager.removeBadge(for: folder) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAddFolder) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 14))
                .frame(width: BarLayoutConstants.pinHitAreaSize, height: BarLayoutConstants.pinHitAreaSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add a folder to peek into")
    }
}

private struct FolderPeekIcon: View {
    let folder: PeekFolder
    let onOpenMenu: (PeekFolder) -> Void
    let onAddFolder: () -> Void
    let onRemove: () -> Void
    let onMoveToStartMenu: () -> Void
    let onSetSortOrder: (FolderSortOrder) -> Void
    let onChooseIcon: () -> Void
    let onResetIcon: () -> Void
    let onChooseBadgeImage: () -> Void
    let onSetBadgeSymbol: (String) -> Void
    let onSetBadgeColor: (FolderBadgeColor) -> Void
    let onRemoveBadge: () -> Void

    @State private var isHovering = false

    private static func swatch(_ color: FolderBadgeColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.nsColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    var body: some View {
        Button(action: { onOpenMenu(folder) }) {
            Image(nsImage: FolderIconRenderer.shared.icon(for: folder))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: BarLayoutConstants.pinIconSize, height: BarLayoutConstants.pinIconSize)
                .frame(width: BarLayoutConstants.pinHitAreaSize, height: BarLayoutConstants.pinHitAreaSize)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.18 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(folder.path)
        .contextMenu {
            Button("Open “\(folder.name)” in Finder") {
                NSWorkspace.shared.open(folder.url)
            }
            Picker("Sort By", selection: Binding(get: { folder.sortOrder }, set: onSetSortOrder)) {
                ForEach(FolderSortOrder.allCases, id: \.self) { order in
                    Text(order.menuTitle).tag(order)
                }
            }
            Menu("Badge") {
                Button("Choose Image…", action: onChooseBadgeImage)
                Divider()
                ForEach(FolderBadgePreset.allCases, id: \.self) { preset in
                    Button {
                        onSetBadgeSymbol(preset.rawValue)
                    } label: {
                        Label(preset.menuTitle, systemImage: preset.rawValue)
                    }
                }
                if folder.badgeImagePath != nil || folder.badgeSymbol != nil {
                    Divider()
                    Button("No Badge", action: onRemoveBadge)
                }
            }
            if folder.badgeSymbol != nil {
                Menu("Badge Color") {
                    ForEach(FolderBadgeColor.allCases, id: \.self) { color in
                        Button {
                            onSetBadgeColor(color)
                        } label: {
                            Label {
                                Text(color.menuTitle)
                            } icon: {
                                Image(nsImage: Self.swatch(color))
                            }
                        }
                    }
                }
            }
            Menu("Icon") {
                Button("Choose Image…", action: onChooseIcon)
                if folder.customIconPath != nil {
                    Button("Use Finder Icon", action: onResetIcon)
                }
            }
            Divider()
            Button("Move to Start Menu", action: onMoveToStartMenu)
            Button("Add Folder…", action: onAddFolder)
            Button("Remove “\(folder.name)”", action: onRemove)
        }
    }
}
