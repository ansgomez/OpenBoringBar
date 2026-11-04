import AppKit
import SwiftUI

/// The bar's upper row: one group per AeroSpace workspace, each with an icon
/// per window. Drag an icon onto another group (or "+") to move the window.
struct WorkspaceRowView: View {
    let groups: [WorkspaceGroup]
    let emptyWorkspaceTarget: String?
    let onSwitchWorkspace: (String) -> Void
    let onFocusWindow: (CGWindowID) -> Void
    let onMoveWindow: (CGWindowID, String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BarLayoutConstants.workspaceGroupSpacing) {
                ForEach(groups) { group in
                    WorkspaceGroupView(
                        group: group,
                        onSwitchWorkspace: onSwitchWorkspace,
                        onFocusWindow: onFocusWindow,
                        onMoveWindow: onMoveWindow
                    )
                }

                if let emptyWorkspaceTarget {
                    WorkspaceEmptyTargetView(
                        workspace: emptyWorkspaceTarget,
                        onMoveWindow: onMoveWindow
                    )
                }
            }
            // No leading inset: groups line up with the pills below.
            .padding(.trailing, 8)
            .frame(maxHeight: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Drag payload: the window ID as text.
enum WorkspaceDragPayload {
    static func windowID(from items: [String]) -> CGWindowID? {
        items.lazy.compactMap { CGWindowID($0) }.first
    }
}

private struct WorkspaceGroupView: View {
    let group: WorkspaceGroup
    let onSwitchWorkspace: (String) -> Void
    let onFocusWindow: (CGWindowID) -> Void
    let onMoveWindow: (CGWindowID, String) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 3) {
            Text(group.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(group.isFocused ? Color.accentColor : Color.primary.opacity(group.isVisible ? 0.9 : 0.6))
                .frame(minWidth: 12)
                .padding(.trailing, 2)
                .contentShape(Rectangle())
                .onTapGesture { onSwitchWorkspace(group.name) }
                .help("Go to workspace \(group.name)")

            ForEach(group.windows) { window in
                WorkspaceWindowIcon(window: window, onFocus: onFocusWindow)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: BarLayoutConstants.workspaceGroupHeight)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.accentColor, lineWidth: isDropTargeted ? 1.5 : 0)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let windowID = WorkspaceDragPayload.windowID(from: items),
                  !group.windows.contains(where: { $0.id == windowID }) else {
                return false
            }
            onMoveWindow(windowID, group.name)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private var backgroundColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.25)
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
