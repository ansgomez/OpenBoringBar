import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

final class DisplayPanelController {
    private static let autoCollapseDefaultsKey = "OpenBoringBar.autoCollapseEnabled"
    /// Hover previews are off; the pill's right-click menu lists windows instead.
    private static let isHoverPreviewEnabled = false

    private let barManager: BarManager
    private let eventBus: AppEventBus
    private var panelStateCancellable: AnyCancellable?
    private var windowsByDisplayID: [CGDirectDisplayID: DisplayPanelWindow] = [:]
    private var previewContextsByDisplayID: [CGDirectDisplayID: DisplayPreviewContext] = [:]
    private var panelHeightByDisplayID: [CGDirectDisplayID: CGFloat] = [:]
    private var isBarHoveringByDisplayID: [CGDirectDisplayID: Bool] = [:]
    private var isCollapsedByDisplayID: [CGDirectDisplayID: Bool] = [:]
    private var collapseHideWorkItemByDisplayID: [CGDirectDisplayID: DispatchWorkItem] = [:]
    private var panelTransitionTargetCollapsedByDisplayID: [CGDirectDisplayID: Bool] = [:]
    private var panelTransitionWorkItemByDisplayID: [CGDirectDisplayID: DispatchWorkItem] = [:]
    private var pointerPollTimer: Timer?
    private var isAutoCollapseEnabled: Bool

    init(barManager: BarManager, eventBus: AppEventBus) {
        self.barManager = barManager
        self.eventBus = eventBus
        self.isAutoCollapseEnabled = UserDefaults.standard.bool(
            forKey: Self.autoCollapseDefaultsKey
        )
    }

    deinit {
        stopPointerPolling()
        for displayID in Array(collapseHideWorkItemByDisplayID.keys) {
            cancelCollapseHideWorkItem(for: displayID)
        }
        for displayID in Array(panelTransitionWorkItemByDisplayID.keys) {
            cancelPanelTransition(for: displayID)
        }
    }

    func start() {
        guard panelStateCancellable == nil else {
            return
        }

        if isAutoCollapseEnabled {
            startPointerPollingIfNeeded()
        }

        panelStateCancellable = Publishers.CombineLatest(
            barManager.$displayStates,
            barManager.$launchableApplications
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] states, launchableApplications in
                self?.syncPanels(with: states, launchableApplications: launchableApplications)
            }

        syncPanels(
            with: barManager.displayStates,
            launchableApplications: barManager.launchableApplications
        )
    }

    func stop() {
        panelStateCancellable?.cancel()
        panelStateCancellable = nil
        stopPointerPolling()

        for displayID in windowsByDisplayID.keys {
            cancelCollapseHideWorkItem(for: displayID)
            cancelPanelTransition(for: displayID)
            postDisplayHeight(0, for: displayID, force: true)
        }

        for panel in windowsByDisplayID.values {
            panel.orderOut(nil)
            panel.close()
        }
        windowsByDisplayID.removeAll()
        panelHeightByDisplayID.removeAll()
        isBarHoveringByDisplayID.removeAll()
        isCollapsedByDisplayID.removeAll()
        panelTransitionTargetCollapsedByDisplayID.removeAll()

        for displayID in Array(previewContextsByDisplayID.keys) {
            closePreviewContext(for: displayID)
        }
    }

    private func syncPanels(
        with states: [DisplayState],
        launchableApplications: [LaunchableApplicationItem]
    ) {
        let activeDisplayIDs = Set(states.map(\.id))

        for (displayID, panel) in Array(windowsByDisplayID) where !activeDisplayIDs.contains(displayID) {
            cancelCollapseHideWorkItem(for: displayID)
            cancelPanelTransition(for: displayID)
            panel.orderOut(nil)
            panel.close()
            windowsByDisplayID.removeValue(forKey: displayID)
            isBarHoveringByDisplayID.removeValue(forKey: displayID)
            isCollapsedByDisplayID.removeValue(forKey: displayID)
            panelTransitionTargetCollapsedByDisplayID.removeValue(forKey: displayID)
            postDisplayHeight(0, for: displayID, force: true)
            panelHeightByDisplayID.removeValue(forKey: displayID)
        }

        for displayID in Array(previewContextsByDisplayID.keys) where !activeDisplayIDs.contains(displayID) {
            closePreviewContext(for: displayID)
        }

        for state in states {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == state.id }) else {
                continue
            }

            let isNewPanel = windowsByDisplayID[state.id] == nil
            let panel = panelForDisplay(state.id)
            updateContent(
                of: panel,
                displayID: state.id,
                with: state.apps,
                pinnedApps: state.pinnedApps,
                runningUnpinnedApps: state.runningUnpinnedApps,
                workspaceGroups: state.workspaceGroups,
                emptyWorkspaceTarget: state.emptyWorkspaceTarget,
                barWidth: state.frame.width,
                launchableApplications: launchableApplications
            )
            updatePanelPresentation(
                of: panel,
                displayID: state.id,
                in: screen,
                animated: !isNewPanel
            )

            if let context = previewContextsByDisplayID[state.id],
               let hoveredPID = context.hoverTarget?.processID,
               !state.apps.contains(where: { $0.processID == hoveredPID }) {
                context.hoverTarget = nil
                if !context.isPointerInsidePreview {
                    schedulePreviewHide(for: state.id, context: context)
                }
            }
        }
    }

    private func panelForDisplay(_ displayID: CGDirectDisplayID) -> DisplayPanelWindow {
        if let existing = windowsByDisplayID[displayID] {
            return existing
        }

        let panel = DisplayPanelWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        windowsByDisplayID[displayID] = panel
        return panel
    }

    private func previewContext(for displayID: CGDirectDisplayID) -> DisplayPreviewContext {
        if let existing = previewContextsByDisplayID[displayID] {
            return existing
        }

        let panel = AppWindowPreviewPanelWindow(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false

        let context = DisplayPreviewContext(panel: panel)
        previewContextsByDisplayID[displayID] = context
        return context
    }

    private func closePreviewContext(for displayID: CGDirectDisplayID) {
        guard let context = previewContextsByDisplayID.removeValue(forKey: displayID) else {
            return
        }

        context.invalidate()
        context.panel.orderOut(nil)
        context.panel.close()
        refreshAutoCollapsePresentation(animated: true)
    }

    private func updateContent(
        of panel: DisplayPanelWindow,
        displayID: CGDirectDisplayID,
        with apps: [RunningAppItem],
        pinnedApps: [PinnedAppItem],
        runningUnpinnedApps: [PinnedAppItem],
        workspaceGroups: [WorkspaceGroup],
        emptyWorkspaceTarget: String?,
        barWidth: CGFloat,
        launchableApplications: [LaunchableApplicationItem]
    ) {
        let content = AnyView(
            DisplayBottomBarView(
                apps: apps,
                pinnedApps: pinnedApps,
                runningUnpinnedApps: runningUnpinnedApps,
                pinStripMaxWidth: barWidth * BarLayoutConstants.pinStripMaxWidthFraction,
                pinDisplayMode: barManager.pinDisplayMode,
                launchableApplications: launchableApplications,
                isAutoCollapseEnabled: isAutoCollapseEnabled,
                hidesOffScreenWindows: barManager.hidesOffScreenWindows,
                isAeroSpaceAvailable: barManager.isAeroSpaceAvailable,
                showsWorkspaces: barManager.showsWorkspaces,
                pillsFollowWorkspace: barManager.pillsFollowWorkspace,
                showsEmptyWorkspaces: barManager.showsEmptyWorkspaces,
                systemStatsMonitor: barManager.systemStatsMonitor,
                showsSystemStats: barManager.showsSystemStats,
                onShowsSystemStatsToggled: { [barManager] isEnabled in
                    barManager.setShowsSystemStats(isEnabled)
                },
                folderPeekManager: barManager.folderPeekManager,
                showsFolders: barManager.showsFolders,
                onShowsFoldersToggled: { [barManager] isEnabled in
                    barManager.setShowsFolders(isEnabled)
                },
                onOpenFolderMenu: { [weak self] folder in
                    self?.showFolderMenu(folder)
                },
                onAddFolder: { [weak self] in
                    self?.promptToAddFolder()
                },
                onChooseImage: { message in
                    Self.promptForImage(message: message)
                },
                workspaceGroups: workspaceGroups,
                emptyWorkspaceTarget: emptyWorkspaceTarget,
                onSwitchWorkspace: { [barManager] workspace in
                    barManager.switchToWorkspace(workspace)
                },
                onFocusWorkspaceWindow: { [barManager] windowID in
                    barManager.focusAeroSpaceWindow(windowID)
                },
                onMoveWindowToWorkspace: { [barManager] windowID, workspace in
                    barManager.moveWindow(windowID, toWorkspace: workspace)
                },
                onShowsWorkspacesToggled: { [barManager] isEnabled in
                    barManager.setShowsWorkspaces(isEnabled)
                },
                onPillsFollowWorkspaceToggled: { [barManager] isEnabled in
                    barManager.setPillsFollowWorkspace(isEnabled)
                },
                onShowsEmptyWorkspacesToggled: { [barManager] isEnabled in
                    barManager.setShowsEmptyWorkspaces(isEnabled)
                },
                onShowStartMenu: { [weak self] in
                    self?.showStartMenu(displayID: displayID)
                },
                onOpenPinnedApp: { [barManager] item in
                    barManager.openPinnedApp(
                        item,
                        displayID: displayID,
                        forcesNewWindow: NSEvent.modifierFlags.contains(.shift)
                    )
                },
                onShowPinMenu: { [weak self] item, availableMoves, event, view in
                    self?.showPinMenu(
                        displayID: displayID,
                        item: item,
                        availableMoves: availableMoves,
                        event: event,
                        view: view
                    )
                },
                onPinDisplayModeChanged: { [barManager] mode in
                    barManager.setPinDisplayMode(mode)
                },
                onSwitch: { [barManager] app in
                    if app.isMinimized, let windowID = app.windowID {
                        barManager.restoreMinimizedWindow(processID: app.processID, windowID: windowID)
                    } else if let windowID = app.windowID {
                        barManager.focusAeroSpaceWindow(windowID)
                    } else {
                        barManager.switchToApp(processID: app.processID, displayID: displayID)
                    }
                },
                onShowAppMenu: { [weak self] processID, event, view in
                    self?.showAppMenu(
                        displayID: displayID,
                        processID: processID,
                        event: event,
                        view: view
                    )
                },
                onOpenApplication: barManager.openApplication(bundleURL:),
                onAppHoverChanged: { [weak self] processID, frameInScreen in
                    self?.handleAppHoverChanged(
                        displayID: displayID,
                        processID: processID,
                        pillFrameInScreen: frameInScreen
                    )
                },
                onBarHoverChanged: { [weak self] isHovering in
                    self?.handleBarHoverChanged(
                        displayID: displayID,
                        isHovering: isHovering
                    )
                },
                onAutoCollapseToggled: { [weak self] isEnabled in
                    self?.handleAutoCollapseToggled(isEnabled: isEnabled)
                },
                onHidesOffScreenWindowsToggled: { [barManager] isEnabled in
                    barManager.setHidesOffScreenWindows(isEnabled)
                },
                onRequestQuit: handleQuitRequested
            )
        )

        if let hostingView = panel.contentView as? NSHostingView<AnyView> {
            hostingView.rootView = content
        } else {
            panel.contentView = NSHostingView(rootView: content)
        }
    }

    private func handleBarHoverChanged(
        displayID: CGDirectDisplayID,
        isHovering: Bool
    ) {
        isBarHoveringByDisplayID[displayID] = isHovering
        guard isAutoCollapseEnabled else {
            return
        }

        refreshAutoCollapsePresentation(animated: true)
    }

    private func handleAutoCollapseToggled(isEnabled: Bool) {
        guard isAutoCollapseEnabled != isEnabled else {
            return
        }

        isAutoCollapseEnabled = isEnabled
        UserDefaults.standard.set(
            isEnabled,
            forKey: Self.autoCollapseDefaultsKey
        )
        if isEnabled {
            startPointerPollingIfNeeded()
        } else {
            stopPointerPolling()
        }

        syncPanels(
            with: barManager.displayStates,
            launchableApplications: barManager.launchableApplications
        )
        refreshAutoCollapsePresentation(animated: true)
    }

    private func startPointerPollingIfNeeded() {
        guard pointerPollTimer == nil else {
            return
        }

        let timer = Timer(
            timeInterval: BarLayoutConstants.autoCollapsePointerPollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshAutoCollapsePresentation(animated: true)
        }
        pointerPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPointerPolling() {
        pointerPollTimer?.invalidate()
        pointerPollTimer = nil
    }

    private func refreshAutoCollapsePresentation(animated: Bool) {
        guard !windowsByDisplayID.isEmpty else {
            return
        }

        for (displayID, panel) in windowsByDisplayID {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else {
                continue
            }

            updatePanelPresentation(
                of: panel,
                displayID: displayID,
                in: screen,
                animated: animated
            )
        }
    }

    private func updatePanelPresentation(
        of panel: DisplayPanelWindow,
        displayID: CGDirectDisplayID,
        in screen: NSScreen,
        animated: Bool
    ) {
        let shouldCollapse = shouldCollapsePanel(displayID: displayID, in: screen)
        let wasCollapsed = isCollapsedByDisplayID[displayID] ?? false
        let isTransitioning = panelTransitionWorkItemByDisplayID[displayID] != nil

        if isTransitioning,
           let transitionTargetCollapsed = panelTransitionTargetCollapsedByDisplayID[displayID],
           transitionTargetCollapsed != shouldCollapse {
            return
        }

        let isStateChanging = shouldCollapse != wasCollapsed
        let shouldAnimateStateTransition = animated && isStateChanging

        if shouldAnimateStateTransition {
            startPanelTransition(
                for: displayID,
                targetCollapsed: shouldCollapse
            )
        } else if !isTransitioning {
            panelTransitionTargetCollapsedByDisplayID.removeValue(forKey: displayID)
        }

        isCollapsedByDisplayID[displayID] = shouldCollapse

        let expandedFrame = expandedFrame(in: screen)
        let collapsedFrame = collapsedFrame(in: screen)

        if shouldCollapse {
            panel.setFrame(
                collapsedFrame,
                display: true,
                animate: shouldAnimateStateTransition
            )
            postDisplayHeight(0, for: displayID)

            let hideAction = { [weak self, weak panel] in
                guard let self, let panel else {
                    return
                }
                self.collapseHideWorkItemByDisplayID[displayID] = nil
                guard self.isCollapsedByDisplayID[displayID] == true else {
                    return
                }
                panel.orderOut(nil)
            }

            cancelCollapseHideWorkItem(for: displayID)
            if shouldAnimateStateTransition {
                let workItem = DispatchWorkItem(block: hideAction)
                collapseHideWorkItemByDisplayID[displayID] = workItem
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + BarLayoutConstants.panelCollapseAnimationDuration,
                    execute: workItem
                )
            } else {
                hideAction()
            }
            return
        }

        cancelCollapseHideWorkItem(for: displayID)
        if !panel.isVisible {
            panel.setFrame(collapsedFrame, display: true)
        }
        panel.orderFrontRegardless()
        if panel.frame != expandedFrame {
            panel.setFrame(
                expandedFrame,
                display: true,
                animate: shouldAnimateStateTransition
            )
        }
        postDisplayHeight(expandedFrame.height, for: displayID)
    }

    private func shouldCollapsePanel(
        displayID: CGDirectDisplayID,
        in screen: NSScreen
    ) -> Bool {
        guard isAutoCollapseEnabled else {
            return false
        }

        if isBarHoveringByDisplayID[displayID] == true {
            return false
        }

        if shouldKeepExpandedForPreview(displayID: displayID) {
            return false
        }

        return !isPointerNearBottom(of: screen)
    }

    private func shouldKeepExpandedForPreview(displayID: CGDirectDisplayID) -> Bool {
        guard let context = previewContextsByDisplayID[displayID] else {
            return false
        }

        return context.panel.isVisible
            || context.hoverTarget != nil
            || context.isPointerInsidePreview
    }

    private func isPointerNearBottom(of screen: NSScreen) -> Bool {
        let pointerLocation = NSEvent.mouseLocation
        guard screen.frame.contains(pointerLocation) else {
            return false
        }

        return pointerLocation.y <=
            (screen.frame.minY + BarLayoutConstants.autoCollapseBottomRevealHotZoneHeight)
    }

    private func expandedFrame(in screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX,
            y: screen.frame.minY,
            width: screen.frame.width,
            height: BarLayoutConstants.panelHeight
        )
    }

    private func collapsedFrame(in screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX,
            y: screen.frame.minY,
            width: screen.frame.width,
            height: 0
        )
    }

    private func cancelCollapseHideWorkItem(for displayID: CGDirectDisplayID) {
        collapseHideWorkItemByDisplayID[displayID]?.cancel()
        collapseHideWorkItemByDisplayID[displayID] = nil
    }

    private func startPanelTransition(
        for displayID: CGDirectDisplayID,
        targetCollapsed: Bool
    ) {
        cancelPanelTransition(for: displayID)
        panelTransitionTargetCollapsedByDisplayID[displayID] = targetCollapsed

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.panelTransitionWorkItemByDisplayID[displayID] = nil
            self.panelTransitionTargetCollapsedByDisplayID.removeValue(forKey: displayID)
            self.refreshAutoCollapsePresentation(animated: true)
        }
        panelTransitionWorkItemByDisplayID[displayID] = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + BarLayoutConstants.panelCollapseAnimationDuration,
            execute: workItem
        )
    }

    private func cancelPanelTransition(for displayID: CGDirectDisplayID) {
        panelTransitionWorkItemByDisplayID[displayID]?.cancel()
        panelTransitionWorkItemByDisplayID[displayID] = nil
        panelTransitionTargetCollapsedByDisplayID.removeValue(forKey: displayID)
    }

    private func postDisplayHeight(
        _ height: CGFloat,
        for displayID: CGDirectDisplayID,
        force: Bool = false
    ) {
        let normalizedHeight = max(0, height)

        if !force,
           let previousHeight = panelHeightByDisplayID[displayID],
           abs(previousHeight - normalizedHeight) < 0.5 {
            return
        }

        panelHeightByDisplayID[displayID] = normalizedHeight
        eventBus.post(
            .barDisplayHeightChanged(
                displayID: displayID,
                height: normalizedHeight
            )
        )
    }

    private func handleAppHoverChanged(
        displayID: CGDirectDisplayID,
        processID: pid_t?,
        pillFrameInScreen: CGRect?
    ) {
        let context = previewContext(for: displayID)

        guard Self.isHoverPreviewEnabled, let processID, let pillFrameInScreen else {
            context.hoverTarget = nil
            if !context.isPointerInsidePreview {
                schedulePreviewHide(for: displayID, context: context)
            }
            refreshAutoCollapsePresentation(animated: true)
            return
        }

        context.hoverTarget = HoverPreviewTarget(
            processID: processID,
            pillFrameInScreen: pillFrameInScreen
        )

        context.hideWorkItem?.cancel()
        context.hideWorkItem = nil

        if context.panel.isVisible {
            showPreview(for: displayID, context: context)
        } else {
            schedulePreviewShow(for: displayID, context: context)
        }
        refreshAutoCollapsePresentation(animated: true)
    }

    private func handlePreviewHoverChanged(
        displayID: CGDirectDisplayID,
        isHovering: Bool
    ) {
        guard let context = previewContextsByDisplayID[displayID] else {
            return
        }

        context.isPointerInsidePreview = isHovering

        if isHovering {
            context.hideWorkItem?.cancel()
            context.hideWorkItem = nil
            refreshAutoCollapsePresentation(animated: true)
            return
        }

        if context.hoverTarget == nil {
            schedulePreviewHide(for: displayID, context: context)
        }
        refreshAutoCollapsePresentation(animated: true)
    }

    private func handlePreviewWindowSelection(
        displayID: CGDirectDisplayID,
        processID: pid_t,
        windowID: CGWindowID
    ) {
        guard previewContextsByDisplayID[displayID] != nil else {
            return
        }

        barManager.activateWindow(
            processID: processID,
            windowID: windowID
        )
    }

    /// Current workspace first, then other workspaces by name; window order
    /// is kept within a workspace. Windows with no known workspace go last.
    private static func sortedByWorkspace(
        _ windows: [(windowID: CGWindowID, title: String)],
        workspaces: AeroSpaceState
    ) -> [(windowID: CGWindowID, title: String)] {
        let workspaceByWindowID = workspaces.workspaceByWindowID
        guard !workspaceByWindowID.isEmpty else {
            return windows
        }

        func rank(_ windowID: CGWindowID) -> (Int, String) {
            guard let workspace = workspaceByWindowID[windowID] else {
                return (2, "")
            }
            return (workspace == workspaces.focusedWorkspace ? 0 : 1, workspace)
        }

        return windows.enumerated().sorted { lhs, rhs in
            let left = rank(lhs.element.windowID)
            let right = rank(rhs.element.windowID)
            if left.0 != right.0 { return left.0 < right.0 }
            if left.1 != right.1 {
                return left.1.localizedStandardCompare(right.1) == .orderedAscending
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// "W  Window title", with the workspace name dimmed unless it is the
    /// workspace on screen. Minimized windows get a dimmed title and a
    /// "minimized" note.
    private static func windowMenuTitle(
        _ title: String,
        workspace: String,
        isCurrent: Bool,
        isMinimized: Bool = false
    ) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let result = NSMutableAttributedString(
            string: workspace,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .semibold),
                .foregroundColor: isCurrent ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
            ]
        )
        result.append(NSAttributedString(
            string: "   \(title)",
            attributes: [
                .font: font,
                .foregroundColor: isMinimized ? NSColor.secondaryLabelColor : NSColor.labelColor
            ]
        ))
        if isMinimized {
            result.append(NSAttributedString(
                string: "  (minimized)",
                attributes: [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
            ))
        }
        return result
    }

    /// Opens the Start menu at the pointer. Blocks until the menu closes, so
    /// the builder (which owns submenu delegates) stays alive.
    private func showStartMenu(displayID: CGDirectDisplayID) {
        let builder = StartMenuBuilder()
        let menu = builder.menu(
            favorites: barManager.favoriteApplications(),
            frequent: barManager.frequentApplications(on: displayID),
            all: barManager.launchableApplications,
            folders: barManager.folderPeekManager.startMenuFolders,
            layouts: barManager.isAeroSpaceAvailable ? barManager.workspaceLayouts() : nil,
            onOpen: { [barManager] url in
                barManager.openApplication(bundleURL: url)
            },
            onRunLayout: { [barManager] layout in
                barManager.runWorkspaceLayout(layout, displayID: displayID)
            },
            onRemoveFavorite: { [barManager] bundleIdentifier in
                barManager.setStartMenuFavorite(false, bundleIdentifier: bundleIdentifier)
            },
            onHideFrequent: { [barManager] bundleIdentifier in
                barManager.hideFromFrequentApplications(bundleIdentifier: bundleIdentifier)
            },
            onMoveFolderToBar: { [barManager] folder in
                barManager.folderPeekManager.setInStartMenu(false, for: folder)
            },
            onRemoveFolder: { [barManager] folder in
                barManager.folderPeekManager.remove(folder)
            }
        )
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        withExtendedLifetime(builder) {}
    }

    /// Opens a folder widget's menu at the pointer. The call blocks until the
    /// menu closes, so the builder (which owns submenu delegates) stays alive.
    private func showFolderMenu(_ folder: PeekFolder) {
        let builder = FolderPeekMenuBuilder()
        let menu = builder.menu(for: folder)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        withExtendedLifetime(builder) {}
    }

    /// Picks an image file; returns its path, or `nil` if cancelled.
    private static func promptForImage(message: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Use Image"
        panel.message = message
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url?.path
    }

    private func promptToAddFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose folders to show in the bar"
        // The bar never activates itself; the panel needs the app in front.
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else {
            return
        }
        for url in panel.urls {
            barManager.folderPeekManager.add(url)
        }
    }

    private func showAppMenu(
        displayID: CGDirectDisplayID,
        processID: pid_t,
        event: NSEvent,
        view: NSView
    ) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        addNewWindowItem(to: menu, processID: processID, displayID: displayID)
        addWindowItems(to: menu, processID: processID, displayID: displayID)

        if let isPinned = barManager.pinState(ofRunningApp: processID, displayID: displayID) {
            let pinItem = ClosureMenuItem(title: isPinned ? "Unpin from Bar" : "Pin to Bar") { [weak self] in
                if isPinned {
                    self?.barManager.unpinRunningApp(processID: processID, displayID: displayID)
                } else {
                    self?.barManager.pinRunningApp(processID: processID, displayID: displayID)
                }
            }
            pinItem.image = NSImage(
                systemSymbolName: isPinned ? "pin.slash" : "pin",
                accessibilityDescription: nil
            )
            menu.addItem(pinItem)
        }
        addStartMenuItem(
            to: menu,
            bundleIdentifier: NSRunningApplication(processIdentifier: processID)?.bundleIdentifier
        )

        addQuitItem(to: menu, processID: processID)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    /// Pin right-click: the app's windows from every workspace (when it
    /// runs), the move and unpin items, then Quit (when it runs).
    private func showPinMenu(
        displayID: CGDirectDisplayID,
        item: PinnedAppItem,
        availableMoves: Set<PinMove>,
        event: NSEvent,
        view: NSView
    ) {
        // A running app that is not pinned: same menu as its pill (New
        // Window, its windows, Pin to Bar, Quit).
        if !item.isPinned, let processID = item.processID {
            showAppMenu(displayID: displayID, processID: processID, event: event, view: view)
            return
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        if let processID = item.processID {
            addNewWindowItem(to: menu, processID: processID, displayID: displayID)
            addWindowItems(to: menu, processID: processID, displayID: displayID)
        }

        if !availableMoves.isEmpty {
            for move in PinMove.allCases {
                let moveItem = ClosureMenuItem(title: move.menuTitle) { [weak self] in
                    self?.barManager.movePin(item, move, displayID: displayID)
                }
                moveItem.image = NSImage(systemSymbolName: move.systemImageName, accessibilityDescription: nil)
                moveItem.isEnabled = availableMoves.contains(move)
                menu.addItem(moveItem)
            }
            menu.addItem(.separator())
        }

        let unpinItem = ClosureMenuItem(title: "Unpin \(item.name)") { [weak self] in
            self?.barManager.unpin(item.pin, displayID: displayID)
        }
        unpinItem.image = NSImage(systemSymbolName: "pin.slash", accessibilityDescription: nil)
        menu.addItem(unpinItem)
        addStartMenuItem(to: menu, bundleIdentifier: item.pin.bundleIdentifier)

        if let processID = item.processID {
            addQuitItem(to: menu, processID: processID)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    /// The app's windows from every workspace, sorted by workspace, then its
    /// minimized windows, then a separator.
    private func addWindowItems(
        to menu: NSMenu,
        processID: pid_t,
        displayID: CGDirectDisplayID
    ) {
        let workspaces = barManager.currentAeroSpaceState()
        let windows = Self.sortedByWorkspace(
            barManager.windowTitles(for: processID, on: displayID),
            workspaces: workspaces
        )
        let workspaceByWindowID = workspaces.workspaceByWindowID
        for window in windows {
            let item = ClosureMenuItem(title: window.title) { [weak self] in
                self?.barManager.activateWindow(
                    processID: processID,
                    windowID: window.windowID
                )
            }
            if let workspace = workspaceByWindowID[window.windowID] {
                item.attributedTitle = Self.windowMenuTitle(
                    window.title,
                    workspace: workspace,
                    isCurrent: workspace == workspaces.focusedWorkspace
                )
            }
            menu.addItem(item)
        }

        let listedIDs = Set(windows.map(\.windowID))
        let minimized = barManager.minimizedWindows(of: processID).filter { !listedIDs.contains($0.id) }
        let appName = NSRunningApplication(processIdentifier: processID)?.localizedName ?? "Window"
        for window in minimized {
            let title = window.title.isEmpty ? appName : window.title
            let item = ClosureMenuItem(title: title) { [weak self] in
                self?.barManager.restoreMinimizedWindow(processID: processID, windowID: window.id)
            }
            item.attributedTitle = Self.windowMenuTitle(
                title,
                workspace: barManager.lastKnownWorkspace(of: window.id) ?? "·",
                isCurrent: false,
                isMinimized: true
            )
            menu.addItem(item)
        }

        if !windows.isEmpty || !minimized.isEmpty {
            menu.addItem(.separator())
        }
    }

    /// "New Window": opens one on the workspace shown on this bar.
    private func addNewWindowItem(
        to menu: NSMenu,
        processID: pid_t,
        displayID: CGDirectDisplayID
    ) {
        let item = ClosureMenuItem(title: "New Window") { [weak self] in
            self?.barManager.openNewWindow(processID: processID, displayID: displayID)
        }
        item.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: nil)
        menu.addItem(item)
        menu.addItem(.separator())
    }

    /// "Add to Start Menu" / "Remove from Start Menu" (the Favorites section).
    /// Nothing for apps without a bundle identifier.
    private func addStartMenuItem(to menu: NSMenu, bundleIdentifier: String?) {
        guard let bundleIdentifier else {
            return
        }
        let isFavorite = barManager.isStartMenuFavorite(bundleIdentifier: bundleIdentifier)
        let item = ClosureMenuItem(title: isFavorite ? "Remove from Start Menu" : "Add to Start Menu") { [weak self] in
            self?.barManager.setStartMenuFavorite(!isFavorite, bundleIdentifier: bundleIdentifier)
        }
        item.image = NSImage(systemSymbolName: isFavorite ? "star.slash" : "star", accessibilityDescription: nil)
        menu.addItem(item)
    }

    private func addQuitItem(to menu: NSMenu, processID: pid_t) {
        let appName = NSRunningApplication(processIdentifier: processID)?.localizedName ?? "App"
        let quitItem = ClosureMenuItem(title: "Quit \(appName)") { [weak self] in
            self?.barManager.quitApplication(processID: processID)
        }
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        menu.addItem(quitItem)
    }

    private func handleQuitRequested() {
        NSApp.terminate(nil)
    }

    private func schedulePreviewShow(
        for displayID: CGDirectDisplayID,
        context: DisplayPreviewContext
    ) {
        context.showWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self, weak context] in
            guard let self, let context else {
                return
            }

            self.showPreview(for: displayID, context: context)
        }

        context.showWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + BarLayoutConstants.previewPanelShowDelay,
            execute: workItem
        )
    }

    private func showPreview(
        for displayID: CGDirectDisplayID,
        context: DisplayPreviewContext
    ) {
        context.showWorkItem = nil

        guard let hoverTarget = context.hoverTarget,
              let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else {
            return
        }

        let previews = barManager.windowPreviews(
            for: hoverTarget.processID,
            on: displayID
        )

        let appName = NSRunningApplication(processIdentifier: hoverTarget.processID)?.localizedName
            ?? "Application"

        let desiredWidth = previewPanelWidth(forWindowCount: previews.count)
        let frame = previewFrame(
            around: hoverTarget.pillFrameInScreen,
            desiredWidth: desiredWidth,
            screenFrame: screen.frame
        )

        updatePreviewPanelContent(
            of: context.panel,
            displayID: displayID,
            processID: hoverTarget.processID,
            appName: appName,
            previews: previews
        )

        if context.panel.frame != frame {
            context.panel.setFrame(frame, display: true, animate: context.panel.isVisible)
        }

        context.panel.orderFrontRegardless()
        refreshAutoCollapsePresentation(animated: true)
    }

    private func schedulePreviewHide(
        for displayID: CGDirectDisplayID,
        context: DisplayPreviewContext
    ) {
        context.showWorkItem?.cancel()
        context.showWorkItem = nil
        context.hideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self, weak context] in
            guard let self, let context else {
                return
            }

            context.hideWorkItem = nil

            guard context.hoverTarget == nil,
                  !context.isPointerInsidePreview else {
                return
            }

            context.panel.orderOut(nil)
            self.refreshAutoCollapsePresentation(animated: true)
        }

        context.hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + BarLayoutConstants.previewPanelHideDelay,
            execute: workItem
        )
    }

    private func updatePreviewPanelContent(
        of panel: AppWindowPreviewPanelWindow,
        displayID: CGDirectDisplayID,
        processID: pid_t,
        appName: String,
        previews: [AppWindowPreviewItem]
    ) {
        let content = AnyView(
            AppWindowPreviewPanelView(
                appName: appName,
                previews: previews,
                onHoverChanged: { [weak self] isHovering in
                    self?.handlePreviewHoverChanged(
                        displayID: displayID,
                        isHovering: isHovering
                    )
                },
                onSelectWindow: { [weak self] windowID in
                    self?.handlePreviewWindowSelection(
                        displayID: displayID,
                        processID: processID,
                        windowID: windowID
                    )
                }
            )
        )

        if let hostingView = panel.contentView as? NSHostingView<AnyView> {
            hostingView.rootView = content
        } else {
            panel.contentView = NSHostingView(rootView: content)
        }
    }

    private func previewPanelWidth(forWindowCount windowCount: Int) -> CGFloat {
        guard windowCount > 0 else {
            return BarLayoutConstants.previewPanelFallbackWidth
        }

        let cardsWidth = CGFloat(windowCount) * BarLayoutConstants.previewCardWidth
        let spacing = CGFloat(max(0, windowCount - 1)) * BarLayoutConstants.previewCardSpacing
        return (BarLayoutConstants.previewPanelPadding * 2) + cardsWidth + spacing
    }

    private func previewFrame(
        around pillFrameInScreen: CGRect,
        desiredWidth: CGFloat,
        screenFrame: CGRect
    ) -> CGRect {
        let maxWidth = max(
            BarLayoutConstants.previewPanelFallbackWidth,
            screenFrame.width - (BarLayoutConstants.previewPanelHorizontalInset * 2)
        )
        let width = min(desiredWidth, maxWidth)
        let height = BarLayoutConstants.previewPanelHeight

        let minX = screenFrame.minX + BarLayoutConstants.previewPanelHorizontalInset
        let maxX = screenFrame.maxX - width - BarLayoutConstants.previewPanelHorizontalInset
        let preferredX = pillFrameInScreen.midX - (width / 2)
        let x = min(max(preferredX, minX), maxX)

        let minY = screenFrame.minY + BarLayoutConstants.previewPanelVerticalGap
        let maxY = screenFrame.maxY - height - BarLayoutConstants.previewPanelVerticalGap
        let preferredY = pillFrameInScreen.maxY + BarLayoutConstants.previewPanelVerticalGap
        let y = min(max(preferredY, minY), maxY)

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct HoverPreviewTarget {
    let processID: pid_t
    let pillFrameInScreen: CGRect
}

private final class DisplayPreviewContext {
    let panel: AppWindowPreviewPanelWindow
    var hoverTarget: HoverPreviewTarget?
    var isPointerInsidePreview = false
    var showWorkItem: DispatchWorkItem?
    var hideWorkItem: DispatchWorkItem?

    init(panel: AppWindowPreviewPanelWindow) {
        self.panel = panel
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        showWorkItem?.cancel()
        showWorkItem = nil
        hideWorkItem?.cancel()
        hideWorkItem = nil
        hoverTarget = nil
        isPointerInsidePreview = false
    }
}

final class DisplayPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Menu item that runs a closure; it is its own target.
