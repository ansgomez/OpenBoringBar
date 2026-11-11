import AppKit
import SwiftUI

/// One group per AeroSpace workspace, in the bar's single row. A group shows
/// an icon per window; with `expandsVisibleWorkspace`, the workspace on screen
/// shows `pills` (the window pills) instead. Drag an icon or pill onto another
/// group (or "+") to move the window. The caller provides the scroll view.
struct WorkspaceRowView<Pills: View>: View {
    let groups: [WorkspaceGroup]
    let emptyWorkspaceTarget: String?
    let expandsVisibleWorkspace: Bool
    let onSwitchWorkspace: (String) -> Void
    let onFocusWindow: (CGWindowID) -> Void
    let onMoveWindow: (CGWindowID, String) -> Void
    @ViewBuilder let pills: () -> Pills

    var body: some View {
        HStack(spacing: BarLayoutConstants.workspaceGroupSpacing) {
            ForEach(groups) { group in
                WorkspaceGroupView(
                    group: group,
                    isExpanded: expandsVisibleWorkspace && group.isVisible,
                    onSwitchWorkspace: onSwitchWorkspace,
                    onFocusWindow: onFocusWindow,
                    onMoveWindow: onMoveWindow,
                    pills: pills
                )
            }

            if let emptyWorkspaceTarget {
                WorkspaceEmptyTargetView(
                    workspace: emptyWorkspaceTarget,
                    onMoveWindow: onMoveWindow
                )
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// Drag payload: the window ID as text.
enum WorkspaceDragPayload {
    static func windowID(from items: [String]) -> CGWindowID? {
        items.lazy.compactMap { CGWindowID($0) }.first
    }
}

private struct WorkspaceGroupView<Pills: View>: View {
    let group: WorkspaceGroup
    /// Show the window pills instead of icons (the workspace on screen).
    let isExpanded: Bool
    let onSwitchWorkspace: (String) -> Void
    let onFocusWindow: (CGWindowID) -> Void
    let onMoveWindow: (CGWindowID, String) -> Void
    @ViewBuilder let pills: () -> Pills

    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: isExpanded ? 5 : 3) {
            Text(group.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(nameColor)
                .frame(minWidth: 12)
                .padding(.trailing, 2)

            if isExpanded {
                pills()
            } else {
                ForEach(group.windows) { window in
                    WorkspaceWindowIcon(window: window, onFocus: onFocusWindow)
                }
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, isExpanded ? 4 : 7)
        .frame(
            height: isExpanded
                ? BarLayoutConstants.workspaceExpandedGroupHeight
                : BarLayoutConstants.workspaceGroupHeight
        )
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.accentColor, lineWidth: isDropTargeted ? 1.5 : 0)
        )
        // The whole group is the click and drop target, over the full row
        // height: the name, the gaps and the padding all switch workspace.
        // Icons keep their own tap (focus that window), which wins over this.
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSwitchWorkspace(group.name) }
        .help("Go to workspace \(group.name)")
        .dropDestination(for: String.self) { items, _ in
            guard let windowID = WorkspaceDragPayload.windowID(from: items),
                  !group.windows.contains(where: { $0.id == windowID }) else {
                return false
            }
            onMoveWindow(windowID, group.name)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    /// Accent for the focused workspace; empty workspaces are the dimmest.
    private var nameColor: Color {
        if group.isFocused {
            return Color.accentColor
        }
        if group.isVisible {
            return Color.primary.opacity(0.9)
        }
        return Color.primary.opacity(group.windows.isEmpty ? 0.35 : 0.6)
    }

    private var backgroundColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.25)
        }
        if isExpanded {
            // Fainter than a compact visible group, so the pills stand out.
            return Color.white.opacity(0.12)
        }
        if group.isVisible {
            return Color.white.opacity(0.22)
        }
        return Color.white.opacity(0.07)
    }
}

private struct WorkspaceWindowIcon: View {
    let window: AeroSpaceWindow
    let onFocus: (CGWindowID) -> Void

    var body: some View {
        Image(nsImage: AppIconProvider.shared.icon(forBundleIdentifier: window.bundleIdentifier))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(
                width: BarLayoutConstants.workspaceIconSize,
                height: BarLayoutConstants.workspaceIconSize
            )
            .contentShape(Rectangle())
            .onTapGesture { onFocus(window.id) }
            .windowDragSource(
                windowID: window.id,
                previewIcon: AppIconProvider.shared.icon(forBundleIdentifier: window.bundleIdentifier)
            )
            .help(window.title.isEmpty ? window.appName : "\(window.appName) — \(window.title)")
    }
}

private struct WorkspaceEmptyTargetView: View {
    let workspace: String
    let onMoveWindow: (CGWindowID, String) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: BarLayoutConstants.workspaceGroupHeight, height: BarLayoutConstants.workspaceGroupHeight)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.primary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                    )
            )
            .dropDestination(for: String.self) { items, _ in
                guard let windowID = WorkspaceDragPayload.windowID(from: items) else {
                    return false
                }
                onMoveWindow(windowID, workspace)
                return true
            } isTargeted: { isDropTargeted = $0 }
            .help("Drop a window here to move it to empty workspace \(workspace)")
    }
}
