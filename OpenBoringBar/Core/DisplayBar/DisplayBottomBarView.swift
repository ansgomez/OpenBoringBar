import AppKit
import SwiftUI

private enum DisplayBottomBarAnimation {
    static let contentSwap = Animation.easeInOut(duration: 0.2)
    static let appListMutation = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let appStateChange = Animation.easeInOut(duration: 0.16)
    static let pillHover = Animation.easeOut(duration: 0.12)
    static let launcherToggle = Animation.spring(response: 0.24, dampingFraction: 0.8)
}

struct DisplayBottomBarView: View {
    let apps: [RunningAppItem]
    let pinnedApps: [PinnedAppItem]
    let runningUnpinnedApps: [PinnedAppItem]
    let pinStripMaxWidth: CGFloat
    let pinDisplayMode: PinDisplayMode
    let launchableApplications: [LaunchableApplicationItem]
    let isAutoCollapseEnabled: Bool
    let hidesOffScreenWindows: Bool
    let isAeroSpaceAvailable: Bool
    let showsWorkspaces: Bool
    let pillsFollowWorkspace: Bool
    let showsEmptyWorkspaces: Bool
    let systemStatsMonitor: SystemStatsMonitor
    let showsSystemStats: Bool
    let onShowsSystemStatsToggled: (Bool) -> Void
    let folderPeekManager: FolderPeekManager
    let showsFolders: Bool
    let onShowsFoldersToggled: (Bool) -> Void
    let onOpenFolderMenu: (PeekFolder) -> Void
    let onAddFolder: () -> Void
    let onChooseImage: (String) -> String?
    let workspaceGroups: [WorkspaceGroup]
    let emptyWorkspaceTarget: String?
    let onSwitchWorkspace: (String) -> Void
    let onFocusWorkspaceWindow: (CGWindowID) -> Void
    let onMoveWindowToWorkspace: (CGWindowID, String) -> Void
    let onShowsWorkspacesToggled: (Bool) -> Void
    let onPillsFollowWorkspaceToggled: (Bool) -> Void
    let onShowsEmptyWorkspacesToggled: (Bool) -> Void
    let onShowStartMenu: () -> Void
    let onOpenPinnedApp: (PinnedAppItem) -> Void
    /// Pin right-click: the item, the moves it allows, the event and view.
    let onShowPinMenu: (PinnedAppItem, Set<PinMove>, NSEvent, NSView) -> Void
    let onPinDisplayModeChanged: (PinDisplayMode) -> Void
    let onSwitch: (RunningAppItem) -> Void
    let onShowAppMenu: (pid_t, NSEvent, NSView) -> Void
    let onOpenApplication: (URL) -> Void
    let onAppHoverChanged: (pid_t?, CGRect?) -> Void
    let onBarHoverChanged: (Bool) -> Void
    let onAutoCollapseToggled: (Bool) -> Void
    let onHidesOffScreenWindowsToggled: (Bool) -> Void
    let onRequestQuit: () -> Void

    @State private var isApplicationLauncherPresented = false

    private var isWorkspaceRowVisible: Bool {
        isAeroSpaceAvailable && showsWorkspaces
    }

    /// The pills are drawn inside the group of the workspace on screen. False
    /// when there is no such group (AeroSpace not running or not answering):
    /// the pills then follow the groups, so they never disappear.
    private var pillsAreInWorkspaceGroup: Bool {
        pillsFollowWorkspace && workspaceGroups.contains { $0.isVisible }
    }

    private var appLayoutAnimationKeys: [String] {
        apps.map { "\($0.id)-\($0.name)" }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )

            HStack(spacing: 8) {
                DisplayBarStartButton(onShowMenu: onShowStartMenu)

                Divider()
                    .padding(.vertical, 9)

                if !pinnedApps.isEmpty || !runningUnpinnedApps.isEmpty {
                    DisplayBarPinnedStrip(
                        pinnedApps: pinnedApps,
                        runningApps: runningUnpinnedApps,
                        rowCount: 1,
                        maxWidth: pinStripMaxWidth,
                        onOpen: onOpenPinnedApp,
                        onShowMenu: onShowPinMenu
                    )

                    Divider()
                        .padding(.vertical, 9)
                }

                Group {
                    if isWorkspaceRowVisible {
                        // One row: workspace groups, the one on screen
                        // holding the pills (Pills Follow Workspace), else
                        // the per-app pills after the groups.
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                WorkspaceRowView(
                                    groups: workspaceGroups,
                                    emptyWorkspaceTarget: emptyWorkspaceTarget,
                                    expandsVisibleWorkspace: pillsAreInWorkspaceGroup,
                                    onSwitchWorkspace: onSwitchWorkspace,
                                    onFocusWindow: onFocusWorkspaceWindow,
                                    onMoveWindow: onMoveWindowToWorkspace,
                                    pills: { appPills }
                                )

                                if !pillsAreInWorkspaceGroup, !apps.isEmpty {
                                    Divider()
                                        .padding(.vertical, 9)

                                    appPills
                                }
                            }
                            .padding(.trailing, 10)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    } else if apps.isEmpty {
                        Text("No windows on this display")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 10)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                )
                            )
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            appPills
                                .padding(.trailing, 10)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            )
                        )
                    }
                }
                .frame(height: BarLayoutConstants.panelHeight)

                if showsFolders {
                    FolderPeekStripView(
                        manager: folderPeekManager,
                        rowCount: 1,
                        onOpenFolderMenu: onOpenFolderMenu,
                        onAddFolder: onAddFolder,
                        onChooseImage: onChooseImage
                    )
                }

                if showsSystemStats {
                    Divider()
                        .padding(.vertical, 9)

                    SystemStatsWidgetsView(
                        monitor: systemStatsMonitor,
                        rowCount: 2
                    )
                }
            }
            .padding(.leading, 8)
            .animation(
                DisplayBottomBarAnimation.contentSwap,
                value: apps.isEmpty
            )
            .animation(
                DisplayBottomBarAnimation.appListMutation,
                value: appLayoutAnimationKeys
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover(perform: onBarHoverChanged)
        .contextMenu {
            barMenuItems
        }
    }

    private var appPills: some View {
        HStack(spacing: 5) {
            ForEach(apps) { app in
                DisplayBarAppPill(
                    app: app,
                    onSwitch: onSwitch,
                    onHoverChanged: onAppHoverChanged
                )
                .overlay(
                    DisplayBarPillRightClickCatcher { event, view in
                        onShowAppMenu(app.processID, event, view)
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var barMenuItems: some View {
        Button(action: onRequestQuit) {
            Label("Quit OpenBoringBar", systemImage: "power")
        }

        Toggle(
            "Auto-collapse",
            isOn: Binding(
                get: { isAutoCollapseEnabled },
                set: onAutoCollapseToggled
            )
        )

        if isAeroSpaceAvailable {
            Toggle(
                "Show Workspaces",
                isOn: Binding(
                    get: { showsWorkspaces },
                    set: onShowsWorkspacesToggled
                )
            )

            Toggle(
                "Show Empty Workspaces",
                isOn: Binding(
                    get: { showsEmptyWorkspaces },
                    set: onShowsEmptyWorkspacesToggled
                )
            )
            .disabled(!showsWorkspaces)

            Toggle(
                "Pills Follow Workspace",
                isOn: Binding(
                    get: { pillsFollowWorkspace },
                    set: onPillsFollowWorkspaceToggled
                )
            )
        }

        Button("Add Folder…", action: onAddFolder)

        Toggle(
            "Show Folders",
            isOn: Binding(
                get: { showsFolders },
                set: onShowsFoldersToggled
            )
        )

        Toggle(
            "Show System Stats",
            isOn: Binding(
                get: { showsSystemStats },
                set: onShowsSystemStatsToggled
            )
        )

        Toggle(
            "Hide Off-Screen Windows",
            isOn: Binding(
                get: { hidesOffScreenWindows },
                set: onHidesOffScreenWindowsToggled
            )
        )

        Picker(
            "Show Pins On",
            selection: Binding(
                get: { pinDisplayMode },
                set: onPinDisplayModeChanged
            )
        ) {
            ForEach(PinDisplayMode.allCases, id: \.self) { mode in
                Text(mode.menuTitle).tag(mode)
            }
        }
    }

    private var applicationLauncherButton: some View {
        Button {
            withAnimation(DisplayBottomBarAnimation.launcherToggle) {
                isApplicationLauncherPresented.toggle()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        Color.white.opacity(
                            isApplicationLauncherPresented ? 0.2 : 0.12
                        )
                    )

                Image(systemName: "square.grid.2x2")
                    .font(.system(size: BarLayoutConstants.launcherBaseFontSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .rotationEffect(
                        .degrees(isApplicationLauncherPresented ? 8 : 0)
                    )
                    .scaleEffect(isApplicationLauncherPresented ? 0.94 : 1)
            }
            .frame(
                width: BarLayoutConstants.launcherButtonSize,
                height: BarLayoutConstants.launcherButtonSize
            )
            .animation(
                DisplayBottomBarAnimation.launcherToggle,
                value: isApplicationLauncherPresented
            )
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isApplicationLauncherPresented,
            attachmentAnchor: .point(.topLeading),
            arrowEdge: .bottom
        ) {
            ApplicationLauncherPopoverView(applications: launchableApplications) { app in
                isApplicationLauncherPresented = false
                onOpenApplication(app.bundleURL)
            }
            .padding(8)
        }
    }
}

/// Opens the Start menu (frequently used apps, all apps, Applications folder).
private struct DisplayBarStartButton: View {
    let onShowMenu: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onShowMenu) {
            Image(systemName: "apple.logo")
                .font(.system(size: BarLayoutConstants.startButtonSymbolSize, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(
                    width: BarLayoutConstants.pinHitAreaSize,
                    height: BarLayoutConstants.pinHitAreaSize
                )
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(isHovering ? 0.18 : 0))
                )
                // Full bar height, so a click at the screen edge still lands.
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Start menu: applications, folders, layouts")
    }
}

/// Pinned app icons at the left of the bar. As wide as its icons, up to
/// `maxWidth`; scrolls sideways past that.
private struct DisplayBarPinnedStrip: View {
    let pinnedApps: [PinnedAppItem]
    /// Running apps that are not pinned, drawn after the pins like in the Dock.
    let runningApps: [PinnedAppItem]
    /// 2 when the bar is tall enough (workspace row shown), else 1. Pins fill
    /// the rows in reading order: top row left to right, then the bottom row.
    let rowCount: Int
    let maxWidth: CGFloat
    let onOpen: (PinnedAppItem) -> Void
    let onShowMenu: (PinnedAppItem, Set<PinMove>, NSEvent, NSView) -> Void

    private var columnCount: Int {
        let rows = max(1, rowCount)
        return (pinnedApps.count + rows - 1) / rows
    }

    private var contentWidth: CGFloat {
        // The row's parts: the pins block, the separator, each running icon.
        var parts: [CGFloat] = []
        if !pinnedApps.isEmpty {
            let columns = CGFloat(columnCount)
            parts.append(columns * BarLayoutConstants.pinHitAreaSize + (columns - 1) * BarLayoutConstants.pinSpacing)
        }
        if !pinnedApps.isEmpty, !runningApps.isEmpty {
            parts.append(Self.runningSeparatorWidth)
        }
        parts += runningApps.map { _ in BarLayoutConstants.pinHitAreaSize }
        return parts.reduce(0, +) + CGFloat(max(0, parts.count - 1)) * BarLayoutConstants.pinSpacing
    }

    private static let runningSeparatorWidth: CGFloat = 7

    private var rows: [[(index: Int, item: PinnedAppItem)]] {
        let indexed = pinnedApps.enumerated().map { (index: $0.offset, item: $0.element) }
        guard columnCount > 0 else {
            return []
        }
        return stride(from: 0, to: indexed.count, by: columnCount).map {
            Array(indexed[$0..<min($0 + columnCount, indexed.count)])
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: BarLayoutConstants.pinSpacing) {
            if !pinnedApps.isEmpty {
            VStack(alignment: .leading, spacing: BarLayoutConstants.pinRowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: BarLayoutConstants.pinSpacing) {
                        ForEach(row, id: \.item.id) { entry in
                            DisplayBarPinnedIcon(
                                item: entry.item,
                                isFirst: entry.index == 0,
                                isLast: entry.index == pinnedApps.count - 1,
                                onOpen: onOpen,
                                onShowMenu: onShowMenu
                            )
                        }
                    }
                }
            }
            }

            if !pinnedApps.isEmpty, !runningApps.isEmpty {
                Divider()
                    .padding(.vertical, 13)
                    .frame(width: Self.runningSeparatorWidth)
            }

            ForEach(runningApps) { item in
                // No moves: these are not pins.
                DisplayBarPinnedIcon(item: item, isFirst: true, isLast: true, onOpen: onOpen, onShowMenu: onShowMenu)
            }
          }
          .frame(maxHeight: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: min(contentWidth, maxWidth))
    }
}

/// App icons of the pin strip by bundle path, so a bar refresh does not ask
/// the system for every icon again. Main thread only.
private enum DisplayBarPinIconCache {
    private static var iconByPath: [String: NSImage] = [:]

    static func icon(forApplicationAt url: URL) -> NSImage {
        if let cached = iconByPath[url.path] {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconByPath[url.path] = icon
        return icon
    }
}

private struct DisplayBarPinnedIcon: View {
    let item: PinnedAppItem
    let isFirst: Bool
    let isLast: Bool
    let onOpen: (PinnedAppItem) -> Void
    let onShowMenu: (PinnedAppItem, Set<PinMove>, NSEvent, NSView) -> Void

    @State private var isHovering = false

    private var availableMoves: Set<PinMove> {
        Set(PinMove.allCases.filter(isMoveAvailable))
    }

    private func isMoveAvailable(_ move: PinMove) -> Bool {
        switch move {
        case .left, .toStart:
            return !isFirst
        case .right, .toEnd:
            return !isLast
        }
    }

    var body: some View {
        Button(action: { onOpen(item) }) {
            VStack(spacing: 1) {
                Image(nsImage: DisplayBarPinIconCache.icon(forApplicationAt: item.resolvedURL))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: BarLayoutConstants.pinIconSize,
                        height: BarLayoutConstants.pinIconSize
                    )

                Circle()
                    .fill(Color.primary.opacity(item.isRunning ? 0.7 : 0))
                    .frame(
                        width: BarLayoutConstants.pinRunningDotSize,
                        height: BarLayoutConstants.pinRunningDotSize
                    )
            }
            .frame(
                width: BarLayoutConstants.pinHitAreaSize,
                height: BarLayoutConstants.pinHitAreaSize
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.18 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.name)
        .onHover { hovering in
            withAnimation(DisplayBottomBarAnimation.pillHover) {
                isHovering = hovering
            }
        }
        // AppKit menu (not .contextMenu) so it can list the app's windows
        // from every workspace and offer Quit, like a pill's menu.
        .overlay(
            DisplayBarPillRightClickCatcher { event, view in
                onShowMenu(item, availableMoves, event, view)
            }
        )
        .animation(DisplayBottomBarAnimation.appStateChange, value: item.isRunning)
    }
}

private struct DisplayBarAppPill: View {
    private static let appNameMaxWidth: CGFloat = 140

    let app: RunningAppItem
    let onSwitch: (RunningAppItem) -> Void
    let onHoverChanged: (pid_t?, CGRect?) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: { onSwitch(app) }) {
            HStack(spacing: 8) {
                DisplayBarAppIcon(processID: app.processID)

                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .italic(app.isMinimized)
                    .foregroundStyle(app.isFrontmost ? Color.black : Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.appNameMaxWidth, alignment: .leading)
                    .contentTransition(.opacity)

                if app.notificationBadgeCount > 0 {
                    DisplayBarAppNotificationBadge(
                        count: app.notificationBadgeCount
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(alignment: .leading)
            // Minimized windows stay on their workspace, dimmed.
            .opacity(app.isMinimized ? 0.5 : 1)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        app.isFrontmost
                            ? Color.white.opacity(0.72)
                            : Color.white.opacity(0.1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        app.isFrontmost
                            ? Color.accentColor.opacity(0.42)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1)
            .shadow(
                color: Color.black.opacity(isHovering ? 0.2 : 0),
                radius: isHovering ? 9 : 0,
                x: 0,
                y: 4
            )
            .background(
                DisplayBarPillHoverTrackingArea { hovering, frameInScreen in
                    withAnimation(DisplayBottomBarAnimation.pillHover) {
                        isHovering = hovering
                    }

                    if hovering {
                        onHoverChanged(app.processID, frameInScreen)
                    } else {
                        onHoverChanged(nil, nil)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        // Per-window pills (Pills Follow Workspace) can be dropped on a
        // workspace in the workspace row.
        .windowDragSource(
            // AeroSpace cannot move a minimized window.
            windowID: app.isMinimized ? nil : app.windowID,
            previewIcon: NSRunningApplication(processIdentifier: app.processID)?.icon
                ?? NSWorkspace.shared.icon(for: .applicationBundle)
        )
        .animation(
            DisplayBottomBarAnimation.appStateChange,
            value: app.isFrontmost
        )
        .animation(
            DisplayBottomBarAnimation.appStateChange,
            value: app.notificationBadgeCount
        )
        .animation(
            DisplayBottomBarAnimation.appListMutation,
            value: app.name
        )
    }
}

private struct DisplayBarAppNotificationBadge: View {
    private static let minimumWidth: CGFloat = 18
    private static let horizontalPadding: CGFloat = 6
    private static let verticalPadding: CGFloat = 2
    private static let maxDisplayedCount = 99

    let count: Int

    private var text: String {
        if count > Self.maxDisplayedCount {
            return "\(Self.maxDisplayedCount)+"
        }
        return String(count)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            .frame(minWidth: Self.minimumWidth)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.red.opacity(0.92))
            )
    }
}

private struct DisplayBarAppIcon: View {
    let processID: pid_t

    private var appIcon: NSImage? {
        NSRunningApplication(processIdentifier: processID)?.icon
    }

    var body: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "app")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
    }
}

/// Takes right-clicks on a pill (so the app menu opens instead of the bar
/// menu) and lets every other event fall through to the SwiftUI button.
private struct DisplayBarPillRightClickCatcher: NSViewRepresentable {
    let onRightClick: (NSEvent, NSView) -> Void

    func makeNSView(context: Context) -> DisplayBarPillRightClickNSView {
        let view = DisplayBarPillRightClickNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: DisplayBarPillRightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }
}

private final class DisplayBarPillRightClickNSView: NSView {
    var onRightClick: ((NSEvent, NSView) -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let eventType = NSApp.currentEvent?.type,
              eventType == .rightMouseDown || eventType == .rightMouseUp else {
            return nil
        }
        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event, self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        nil
    }
}

private struct DisplayBarPillHoverTrackingArea: NSViewRepresentable {
    let onHoverChanged: (Bool, CGRect) -> Void

    func makeNSView(context: Context) -> DisplayBarPillHoverTrackingNSView {
        let view = DisplayBarPillHoverTrackingNSView()
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: DisplayBarPillHoverTrackingNSView, context: Context) {
        nsView.onHoverChanged = onHoverChanged
    }
}

private final class DisplayBarPillHoverTrackingNSView: NSView {
    var onHoverChanged: ((Bool, CGRect) -> Void)?

    private var trackingAreaRef: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        notifyHoverChanged(isHovering: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        notifyHoverChanged(isHovering: false)
    }

    private func notifyHoverChanged(isHovering: Bool) {
        guard let window else {
            return
        }

        let frameInWindow = convert(bounds, to: nil)
        let frameInScreen = window.convertToScreen(frameInWindow)
        onHoverChanged?(isHovering, frameInScreen)
    }
}
