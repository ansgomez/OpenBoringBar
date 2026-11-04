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
    let pinStripMaxWidth: CGFloat
    let pinDisplayMode: PinDisplayMode
    let launchableApplications: [LaunchableApplicationItem]
    let isAutoCollapseEnabled: Bool
    let hidesOffScreenWindows: Bool
    let isAeroSpaceAvailable: Bool
    let showsWorkspaces: Bool
    let pillsFollowWorkspace: Bool
    let workspaceGroups: [WorkspaceGroup]
    let emptyWorkspaceTarget: String?
    let onSwitchWorkspace: (String) -> Void
    let onFocusWorkspaceWindow: (CGWindowID) -> Void
    let onMoveWindowToWorkspace: (CGWindowID, String) -> Void
    let onShowsWorkspacesToggled: (Bool) -> Void
    let onPillsFollowWorkspaceToggled: (Bool) -> Void
    let onOpenPinnedApp: (PinnedAppItem) -> Void
    let onUnpinPinnedApp: (PinnedAppItem) -> Void
    let onMovePinnedApp: (PinnedAppItem, PinMove) -> Void
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

            VStack(spacing: 0) {
                if isAeroSpaceAvailable && showsWorkspaces {
                    WorkspaceRowView(
                        groups: workspaceGroups,
                        emptyWorkspaceTarget: emptyWorkspaceTarget,
                        onSwitchWorkspace: onSwitchWorkspace,
                        onFocusWindow: onFocusWorkspaceWindow,
                        onMoveWindow: onMoveWindowToWorkspace
                    )
                    .frame(height: BarLayoutConstants.workspaceRowHeight)

                    Divider()
                        .padding(.horizontal, 8)
                }

                HStack(spacing: 8) {
// Pseudo-requirement: users can already open the app they want with Command + Space, so we shouldn’t blindly copy BoringBar wholesale.
//                applicationLauncherButton
//
//                Divider()
//                    .padding(.vertical, 9)

                    if !pinnedApps.isEmpty {
                        DisplayBarPinnedStrip(
                            pinnedApps: pinnedApps,
                            maxWidth: pinStripMaxWidth,
                            onOpen: onOpenPinnedApp,
                            onUnpin: onUnpinPinnedApp,
                            onMove: onMovePinnedApp
                        )

                        Divider()
                            .padding(.vertical, 9)
                    }

                    Group {
                        if apps.isEmpty {
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
                .frame(height: BarLayoutConstants.panelHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover(perform: onBarHoverChanged)
        .contextMenu {
            barMenuItems
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
                "Pills Follow Workspace",
                isOn: Binding(
                    get: { pillsFollowWorkspace },
                    set: onPillsFollowWorkspaceToggled
                )
            )
        }

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

/// Pinned app icons at the left of the bar. As wide as its icons, up to
/// `maxWidth`; scrolls sideways past that.
private struct DisplayBarPinnedStrip: View {
    let pinnedApps: [PinnedAppItem]
    let maxWidth: CGFloat
    let onOpen: (PinnedAppItem) -> Void
    let onUnpin: (PinnedAppItem) -> Void
    let onMove: (PinnedAppItem, PinMove) -> Void

    private var contentWidth: CGFloat {
        let count = CGFloat(pinnedApps.count)
        return count * BarLayoutConstants.pinHitAreaSize
            + max(0, count - 1) * BarLayoutConstants.pinSpacing
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BarLayoutConstants.pinSpacing) {
                ForEach(Array(pinnedApps.enumerated()), id: \.element.id) { index, item in
                    DisplayBarPinnedIcon(
                        item: item,
                        isFirst: index == 0,
                        isLast: index == pinnedApps.count - 1,
                        onOpen: onOpen,
                        onUnpin: onUnpin,
                        onMove: onMove
                    )
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: min(contentWidth, maxWidth))
    }
}

private struct DisplayBarPinnedIcon: View {
    let item: PinnedAppItem
    let isFirst: Bool
    let isLast: Bool
    let onOpen: (PinnedAppItem) -> Void
    let onUnpin: (PinnedAppItem) -> Void
    let onMove: (PinnedAppItem, PinMove) -> Void

    @State private var isHovering = false

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
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.resolvedURL.path))
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
        .contextMenu {
            if !(isFirst && isLast) {
                ForEach(PinMove.allCases, id: \.self) { move in
                    Button {
                        onMove(item, move)
                    } label: {
                        Label(move.menuTitle, systemImage: move.systemImageName)
                    }
                    .disabled(!isMoveAvailable(move))
                }

                Divider()
            }

            Button {
                onUnpin(item)
            } label: {
                Label("Unpin \(item.name)", systemImage: "pin.slash")
            }
        }
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
            windowID: app.windowID,
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
