import AppKit
import ApplicationServices
import Combine

final class BarManager: ObservableObject {
    @Published private(set) var displayStates: [DisplayState]
    @Published private(set) var launchableApplications: [LaunchableApplicationItem]

    private let eventBus: AppEventBus
    private let installedApplicationProvider: InstalledApplicationProviding
    private let windowPreviewProvider: WindowPreviewProviding
    private let workspaceManager: AeroSpaceWorkspaceManager
    /// Observed directly by the status widgets.
    let systemStatsMonitor: SystemStatsMonitor
    /// Observed directly by the folder widgets.
    let folderPeekManager: FolderPeekManager
    private let dockNotificationBadgeProvider: DockNotificationBadgeProviding
    private let displayStateBuilder: BarDisplayStateBuilder
    private let accessibilityObserverManager: BarAccessibilityObserverManager
    private let pinnedAppManager: PinnedAppManager
    private let appUsageManager: AppUsageManager
    private let workspaceNotificationCenter: NotificationCenter

    /// Apps with a new-window request in flight (main thread only).
    private var openingNewWindowProcessIDs = Set<pid_t>()
    private var displayObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol]
    private var pendingRefreshWorkItem: DispatchWorkItem?

    private let refreshDebounceInterval: TimeInterval = 0.10

    private static let hidesOffScreenWindowsDefaultsKey = "OpenBoringBar.hideOffScreenWindows"

    /// Whether the bar ignores windows parked off-screen by window managers
    /// such as AeroSpace. On by default.
    private(set) var hidesOffScreenWindows: Bool

    init(
        eventBus: AppEventBus,
        installedApplicationProvider: InstalledApplicationProviding = InstalledApplicationProvider(),
        windowPreviewProvider: WindowPreviewProviding = WindowPreviewProvider(),
        workspaceManager: AeroSpaceWorkspaceManager = AeroSpaceWorkspaceManager(),
        systemStatsMonitor: SystemStatsMonitor = SystemStatsMonitor(),
        folderPeekManager: FolderPeekManager = FolderPeekManager(),
        dockNotificationBadgeProvider: DockNotificationBadgeProviding = DockNotificationBadgeProvider(),
        displayStateBuilder: BarDisplayStateBuilder = BarDisplayStateBuilder(),
        accessibilityObserverManager: BarAccessibilityObserverManager = BarAccessibilityObserverManager(),
        pinnedAppManager: PinnedAppManager = PinnedAppManager(
            storage: PinnedAppStorageProvider(),
            locator: ApplicationLocationProvider()
        ),
        appUsageManager: AppUsageManager = AppUsageManager(storage: AppUsageStorageProvider())
    ) {
        self.displayStates = []
        self.launchableApplications = []
        self.eventBus = eventBus
        self.installedApplicationProvider = installedApplicationProvider
        self.windowPreviewProvider = windowPreviewProvider
        self.workspaceManager = workspaceManager
        self.systemStatsMonitor = systemStatsMonitor
        self.folderPeekManager = folderPeekManager
        self.dockNotificationBadgeProvider = dockNotificationBadgeProvider
        self.displayStateBuilder = displayStateBuilder
        self.accessibilityObserverManager = accessibilityObserverManager
        self.pinnedAppManager = pinnedAppManager
        self.appUsageManager = appUsageManager
        self.workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        self.workspaceObservers = []
        self.hidesOffScreenWindows = UserDefaults.standard.object(
            forKey: Self.hidesOffScreenWindowsDefaultsKey
        ) as? Bool ?? true
        self.displayStateBuilder.hidesOffScreenWindows = hidesOffScreenWindows

        self.accessibilityObserverManager.onObservedChange = { [weak self] in
            self?.scheduleDisplayRefresh()
            // Windows opened, closed, moved or retitled: AeroSpace may have
            // re-tiled. Throttled, since these events can come in bursts.
            self?.workspaceManager.refreshThrottled()
        }
        self.dockNotificationBadgeProvider.onBadgeStateChanged = { [weak self] in
            self?.scheduleDisplayRefresh()
        }
        self.workspaceManager.onStateChanged = { [weak self] in
            self?.scheduleDisplayRefresh()
        }

        configureDisplayObserver()
        configureWorkspaceObservers()
        self.accessibilityObserverManager.installObserversForRunningApps()
        self.dockNotificationBadgeProvider.startObserving()

        refreshDisplayStates()
        refreshLaunchableApplications()
        self.workspaceManager.start()
    }

    deinit {
        pendingRefreshWorkItem?.cancel()
        pendingRefreshWorkItem = nil
        accessibilityObserverManager.teardownAllObservers()
        dockNotificationBadgeProvider.stopObserving()

        if let displayObserver {
            NotificationCenter.default.removeObserver(displayObserver)
        }

        teardownWorkspaceObservers()
    }

    func activate(processID: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: processID),
              !app.isTerminated else {
            return
        }

        let previousFrontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        _ = app.unhide()
        _ = restoreFirstMinimizedWindowIfNoVisibleWindow(of: processID)

        let requestAccepted: Bool
        if #available(macOS 14.0, *) {
            // Ensure our process is active before yielding focus to the target app.
            NSApp.activate()
            NSApp.yieldActivation(to: app)
            requestAccepted = app.activate(from: .current, options: [.activateAllWindows])
        } else {
            NSApp.activate(ignoringOtherApps: true)
            requestAccepted = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        if !requestAccepted {
            reopen(app)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else {
                return
            }

            if !app.isActive {
                self.reopen(app)
            }

            _ = self.restoreFirstMinimizedWindowIfNoVisibleWindow(of: processID)
            let currentFrontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if previousFrontmostPID != processID, currentFrontmostPID == processID {
                self.eventBus.post(.capsuleAppSwitchConfirmed(processID: processID))
            }
            self.refreshDisplayStates()
        }
    }

    func openApplication(bundleURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] _, _ in
            self?.refreshDisplayStates()
        }
    }

    /// Pill click. Brings the app forward; if it is already in front, steps
    /// through its windows on `displayID`. Never minimizes.
    func switchToApp(processID: pid_t, displayID: CGDirectDisplayID) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else {
            activate(processID: processID)
            return
        }

        let windowsOnDisplay = windowPreviewProvider.orderedWindowIDs(
            for: processID,
            displayID: displayID
        )
        guard let frontWindowOnDisplay = windowsOnDisplay.first else {
            // No visible window here (e.g. all minimized): restore path.
            activate(processID: processID)
            return
        }

        let frontWindowOverall = windowPreviewProvider.orderedWindowIDs(
            for: processID,
            displayID: nil
        ).first
        if frontWindowOverall != frontWindowOnDisplay {
            // App is in front, but its active window is on another display.
            activateWindow(processID: processID, windowID: frontWindowOnDisplay)
            return
        }

        // Raising the rearmost window each click visits every window in a loop.
        guard windowsOnDisplay.count > 1, let rearmostWindow = windowsOnDisplay.last else {
            return
        }
        activateWindow(processID: processID, windowID: rearmostWindow)
    }

    // MARK: Pinned apps

    var pinDisplayMode: PinDisplayMode {
        pinnedAppManager.mode
    }

    func setHidesOffScreenWindows(_ isEnabled: Bool) {
        guard hidesOffScreenWindows != isEnabled else {
            return
        }
        hidesOffScreenWindows = isEnabled
        displayStateBuilder.hidesOffScreenWindows = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.hidesOffScreenWindowsDefaultsKey)
        scheduleDisplayRefresh()
    }

    func setPinDisplayMode(_ mode: PinDisplayMode) {
        pinnedAppManager.setMode(mode)
        scheduleDisplayRefresh()
    }

    /// Pin click. Launches the app when it is not running. When it runs and
    /// AeroSpace is in use, the click stays on the workspace shown on that
    /// bar (`PinClickRule`): it focuses the app's window there, or opens a
    /// new window there. `forcesNewWindow` (Shift-click) always opens one.
    /// Without AeroSpace it brings the app forward, like the Dock.
    func openPinnedApp(
        _ item: PinnedAppItem,
        displayID: CGDirectDisplayID,
        forcesNewWindow: Bool = false
    ) {
        // A running app that is not pinned needs no lookup: its location is known.
        guard let url = item.isPinned ? pinnedAppManager.resolvedURL(for: item.pin) : item.resolvedURL else {
            NSLog("OpenBoringBar: pinned app not found: \(item.pin.bundleIdentifier ?? item.pin.bundleURL.path)")
            NSSound.beep()
            scheduleDisplayRefresh()
            return
        }
        guard let processID = item.processID else {
            openApplication(bundleURL: url)
            return
        }
        guard workspaceManager.isAvailable else {
            if forcesNewWindow {
                openNewWindow(processID: processID, in: .empty, workspace: nil, isExplicitRequest: true)
            } else {
                openApplication(bundleURL: url)
            }
            return
        }

        let state = workspaceManager.fetchStateNow()
        let action = PinClickRule.action(
            in: state,
            screenNumber: Self.screenNumber(of: displayID),
            processID: processID,
            forcesNewWindow: forcesNewWindow
        )
        switch action {
        case .focusWindow(let windowID):
            workspaceManager.focusWindow(windowID)
        case .openNewWindow(let workspace):
            openNewWindow(processID: processID, in: state, workspace: workspace, isExplicitRequest: forcesNewWindow)
        case .activate:
            activate(processID: processID)
        }
    }

    /// Opens a new window of a running app on the workspace shown on the
    /// given display, without going to the app's other windows.
    func openNewWindow(processID: pid_t, displayID: CGDirectDisplayID) {
        let state = workspaceManager.fetchStateNow()
        openNewWindow(
            processID: processID,
            in: state,
            workspace: PinClickRule.targetWorkspace(in: state, screenNumber: Self.screenNumber(of: displayID)),
            isExplicitRequest: true
        )
    }

    /// Presses the app's New Window menu item, then has AeroSpace focus the
    /// window that appears (moving it to `workspace` if needed). Falls back
    /// to bringing the app forward when the app has no such menu item or no
    /// window appears. `isExplicitRequest` is false for a plain pin click,
    /// which presses fewer kinds of menu item (`NewWindowMenuItemRule`).
    /// Ignored while an earlier request for the same app is still running,
    /// so a double click opens one window.
    private func openNewWindow(
        processID: pid_t,
        in state: AeroSpaceState,
        workspace: String?,
        isExplicitRequest: Bool
    ) {
        guard openingNewWindowProcessIDs.insert(processID).inserted else {
            return
        }
        let knownWindowIDs = Set(state.windows.filter { $0.processID == processID }.map(\.id))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let didPress = AppNewWindowProvider.openNewWindow(
                processID: processID,
                isExplicitRequest: isExplicitRequest
            )
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                guard didPress, let workspace, self.workspaceManager.isAvailable else {
                    self.openingNewWindowProcessIDs.remove(processID)
                    self.activate(processID: processID)
                    return
                }
                self.workspaceManager.focusNewWindow(
                    ofProcessID: processID,
                    knownWindowIDs: knownWindowIDs,
                    onWorkspace: workspace
                ) { [weak self] didFocus in
                    self?.openingNewWindowProcessIDs.remove(processID)
                    if !didFocus {
                        self?.activate(processID: processID)
                    }
                }
            }
        }
    }

    /// 1-based index into `NSScreen.screens`, as AeroSpace numbers monitors.
    private static func screenNumber(of displayID: CGDirectDisplayID) -> Int? {
        NSScreen.screens.firstIndex { $0.displayID == displayID }.map { $0 + 1 }
    }

    /// `nil` when the app cannot be pinned (no bundle) or this bar cannot
    /// edit pins; otherwise whether it is pinned on this bar.
    func pinState(
        ofRunningApp processID: pid_t,
        displayID: CGDirectDisplayID
    ) -> Bool? {
        let context = pinContext(for: displayID)
        guard pinnedAppManager.canEditPins(isMainDisplay: context.isMainDisplay),
              let app = pinnedApp(forProcessID: processID) else {
            return nil
        }
        return pinnedAppManager.isPinned(
            app,
            displayUUID: context.displayUUID,
            isMainDisplay: context.isMainDisplay
        )
    }

    func pinRunningApp(processID: pid_t, displayID: CGDirectDisplayID) {
        guard let app = pinnedApp(forProcessID: processID) else {
            return
        }
        let context = pinContext(for: displayID)
        pinnedAppManager.pin(app, displayUUID: context.displayUUID, isMainDisplay: context.isMainDisplay)
        scheduleDisplayRefresh()
    }

    func unpinRunningApp(processID: pid_t, displayID: CGDirectDisplayID) {
        guard let app = pinnedApp(forProcessID: processID) else {
            return
        }
        unpin(app, displayID: displayID)
    }

    func unpin(_ pin: PinnedApp, displayID: CGDirectDisplayID) {
        let context = pinContext(for: displayID)
        pinnedAppManager.unpin(pin, displayUUID: context.displayUUID, isMainDisplay: context.isMainDisplay)
        scheduleDisplayRefresh()
    }

    /// Reorders a pin among the icons drawn on this bar.
    func movePin(_ item: PinnedAppItem, _ move: PinMove, displayID: CGDirectDisplayID) {
        guard let visiblePins = displayStates.first(where: { $0.id == displayID })?.pinnedApps.map(\.pin),
              let index = visiblePins.firstIndex(of: item.pin) else {
            return
        }

        let anchor: PinnedApp?
        switch move {
        case .left:
            guard index > 0 else { return }
            anchor = visiblePins[index - 1]
        case .right:
            guard index < visiblePins.count - 1 else { return }
            anchor = index + 2 < visiblePins.count ? visiblePins[index + 2] : nil
        case .toStart:
            guard index > 0 else { return }
            anchor = visiblePins[0]
        case .toEnd:
            guard index < visiblePins.count - 1 else { return }
            anchor = nil
        }

        let context = pinContext(for: displayID)
        pinnedAppManager.move(
            item.pin,
            before: anchor,
            displayUUID: context.displayUUID,
            isMainDisplay: context.isMainDisplay
        )
        scheduleDisplayRefresh()
    }

    private func pinnedApp(forProcessID processID: pid_t) -> PinnedApp? {
        guard let app = NSRunningApplication(processIdentifier: processID),
              let bundleURL = app.bundleURL,
              bundleURL.pathExtension == "app" else {
            return nil
        }
        return PinnedApp(bundleIdentifier: app.bundleIdentifier, bundleURL: bundleURL)
    }

    private func pinContext(for displayID: CGDirectDisplayID) -> (displayUUID: String?, isMainDisplay: Bool) {
        (
            NSScreen.displayUUIDString(for: displayID),
            NSScreen.screens.first?.displayID == displayID
        )
    }

    private func attachPins(to states: [DisplayState]) -> [DisplayState] {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications
        let descriptor: (NSRunningApplication) -> RunningAppDescriptor = {
            RunningAppDescriptor(
                bundleIdentifier: $0.bundleIdentifier,
                bundleURL: $0.bundleURL,
                processID: $0.processIdentifier,
                name: $0.localizedName
            )
        }
        let runningApps = applications.map(descriptor)
        // Apps the Dock would show: regular ones, in launch order.
        let dockApps = applications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ownProcessID }
            .map(descriptor)

        return states.map { state in
            var state = state
            let context = pinContext(for: state.id)
            state.displayUUID = context.displayUUID
            state.isMainDisplay = context.isMainDisplay
            state.canEditPins = pinnedAppManager.canEditPins(isMainDisplay: context.isMainDisplay)
            // Pins that cannot be found are kept but not drawn.
            let pins: [(pin: PinnedApp, resolvedURL: URL)] = pinnedAppManager
                .pins(forDisplayUUID: context.displayUUID, isMainDisplay: context.isMainDisplay)
                .compactMap { pin in
                    pinnedAppManager.resolvedURL(for: pin).map { (pin: pin, resolvedURL: $0) }
                }
            // No pin strip on this bar (Main Display Only): no running apps either.
            if state.canEditPins {
                state.runningUnpinnedApps = PinnedAppMatcher.unpinnedRunningApps(
                    among: dockApps,
                    pins: pins.map { (pin: $0.pin, resolvedURL: $0.resolvedURL) }
                ).compactMap { running in
                    guard let url = running.bundleURL else {
                        return nil
                    }
                    return PinnedAppItem(
                        pin: PinnedApp(bundleIdentifier: running.bundleIdentifier, bundleURL: url),
                        resolvedURL: url,
                        name: running.name ?? Self.displayName(ofApplicationAt: url),
                        processID: running.processID,
                        isPinned: false
                    )
                }
            }
            state.pinnedApps = pins.map { pin, url in
                PinnedAppItem(
                    pin: pin,
                    resolvedURL: url,
                    name: Self.displayName(ofApplicationAt: url),
                    processID: PinnedAppMatcher.runningMatch(
                        pin,
                        resolvedURL: url,
                        among: runningApps
                    )?.processID
                )
            }
            return state
        }
    }

    /// Display names by bundle path; read on every bar refresh (main thread).
    private static var displayNameByPath: [String: String] = [:]

    private static func displayName(ofApplicationAt url: URL) -> String {
        if let cached = displayNameByPath[url.path] {
            return cached
        }
        let fileName = FileManager.default.displayName(atPath: url.path)
        let name = fileName.hasSuffix(".app") ? String(fileName.dropLast(4)) : fileName
        displayNameByPath[url.path] = name
        return name
    }

    func quitApplication(processID: pid_t) {
        guard processID != ProcessInfo.processInfo.processIdentifier,
              let application = NSRunningApplication(processIdentifier: processID) else {
            return
        }

        // Polite quit, same as the Dock's "Quit": the app may ask to save documents.
        application.terminate()
    }

    func activateWindow(
        processID: pid_t,
        windowID: CGWindowID
    ) {
        let previousFrontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        let didActivateSpecificWindow = windowPreviewProvider.activateWindow(
            windowID: windowID,
            processID: processID
        )

        guard didActivateSpecificWindow else {
            activate(processID: processID)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else {
                return
            }

            let currentFrontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if previousFrontmostPID != processID, currentFrontmostPID == processID {
                self.eventBus.post(.capsuleAppSwitchConfirmed(processID: processID))
            }
            self.refreshDisplayStates()
        }
    }

    func windowTitles(
        for processID: pid_t,
        on displayID: CGDirectDisplayID
    ) -> [(windowID: CGWindowID, title: String)] {
        windowPreviewProvider.windowTitles(for: processID, displayID: displayID)
    }

    // MARK: System stats widgets

    var showsSystemStats: Bool { systemStatsMonitor.isEnabled }

    func setShowsSystemStats(_ isEnabled: Bool) {
        systemStatsMonitor.setEnabled(isEnabled)
        scheduleDisplayRefresh()
    }

    var showsFolders: Bool { folderPeekManager.isEnabled }

    func setShowsFolders(_ isEnabled: Bool) {
        folderPeekManager.setEnabled(isEnabled)
        scheduleDisplayRefresh()
    }

    // MARK: AeroSpace workspaces

    var isAeroSpaceAvailable: Bool { workspaceManager.isAvailable }
    var showsWorkspaces: Bool { workspaceManager.showsWorkspaces }
    var isWorkspaceRowVisible: Bool { workspaceManager.isRowVisible }
    var pillsFollowWorkspace: Bool { workspaceManager.pillsFollowWorkspace }

    var showsEmptyWorkspaces: Bool { workspaceManager.showsEmptyWorkspaces }

    func setShowsEmptyWorkspaces(_ isEnabled: Bool) {
        workspaceManager.setShowsEmptyWorkspaces(isEnabled)
    }

    func setPillsFollowWorkspace(_ isEnabled: Bool) {
        workspaceManager.setPillsFollowWorkspace(isEnabled)
    }

    func setShowsWorkspaces(_ isEnabled: Bool) {
        workspaceManager.setShowsWorkspaces(isEnabled)
    }

    /// Fresh AeroSpace state, read synchronously (for menus).
    func currentAeroSpaceState() -> AeroSpaceState {
        workspaceManager.fetchStateNow()
    }

    /// Frames of on-screen normal windows, keyed by window number.
    private static func onScreenWindowFrames() -> [CGWindowID: CGRect] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return [:]
        }
        var frames: [CGWindowID: CGRect] = [:]
        for info in windowList {
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else {
                continue
            }
            frames[CGWindowID(number.uint32Value)] = frame
        }
        return frames
    }

    func moveWindow(_ windowID: CGWindowID, toWorkspace workspace: String) {
        workspaceManager.moveWindow(windowID, toWorkspace: workspace)
    }

    func focusAeroSpaceWindow(_ windowID: CGWindowID) {
        workspaceManager.focusWindow(windowID)
    }

    /// Minimized windows of one app, for its window menu.
    func minimizedWindows(of processID: pid_t) -> [MinimizedWindow] {
        MinimizedWindowProvider.minimizedWindows().filter { $0.processID == processID }
    }

    /// Workspace a window was last seen on, also after it was minimized.
    func lastKnownWorkspace(of windowID: CGWindowID) -> String? {
        workspaceManager.lastKnownWorkspaceByWindowID[windowID]
    }

    /// Un-minimizes a window on the workspace it was minimized from. AeroSpace
    /// adds a restored window to the focused workspace, so that workspace is
    /// focused first.
    func restoreMinimizedWindow(processID: pid_t, windowID: CGWindowID) {
        guard let workspace = lastKnownWorkspace(of: windowID),
              workspaceManager.isAvailable,
              workspace != workspaceManager.state.focusedWorkspace else {
            activateWindow(processID: processID, windowID: windowID)
            return
        }
        workspaceManager.switchToWorkspace(workspace)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.activateWindow(processID: processID, windowID: windowID)
        }
    }

    func switchToWorkspace(_ workspace: String) {
        workspaceManager.switchToWorkspace(workspace)
    }

    private func attachWorkspaces(
        to states: [DisplayState],
        badgeCountByProcessID: [pid_t: Int]
    ) -> [DisplayState] {
        let showsRow = workspaceManager.isRowVisible
        let followsWorkspace = workspaceManager.isPillsFollowingWorkspace
        guard showsRow || followsWorkspace else {
            return states
        }
        let aeroSpaceState = workspaceManager.state
        let frameByWindowID = followsWorkspace ? Self.onScreenWindowFrames() : [:]
        let screens = NSScreen.screens
        let minimizedWindows = followsWorkspace ? MinimizedWindowProvider.minimizedWindows() : []
        let lastKnownWorkspace = workspaceManager.lastKnownWorkspaceByWindowID
        let listedWindowIDs = Set(aeroSpaceState.windows.map(\.id))
        let screenBounds = screens.map { $0.displayID.map(CGDisplayBounds) ?? .null }
        let screenNumberOf: (MinimizedWindow) -> Int = { window in
            let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
            return (screenBounds.firstIndex { $0.contains(center) } ?? 0) + 1
        }
        return states.map { state in
            var state = state
            guard let index = screens.firstIndex(where: { $0.displayID == state.id }) else {
                return state
            }
            let screenNumber = index + 1

            if followsWorkspace {
                state.apps = WorkspaceGroupBuilder.visibleWorkspaceWindows(
                    in: aeroSpaceState,
                    screenNumber: screenNumber,
                    frameByWindowID: frameByWindowID
                ).compactMap { window in
                    guard let processID = window.processID else {
                        return nil
                    }
                    return RunningAppItem(
                        processID: processID,
                        name: window.title.isEmpty ? window.appName : window.title,
                        isFrontmost: window.id == aeroSpaceState.focusedWindowID,
                        notificationBadgeCount: max(0, badgeCountByProcessID[processID] ?? 0),
                        windowID: window.id
                    )
                }

                if let visible = aeroSpaceState.workspaces.first(where: {
                    $0.screenNumber == screenNumber && $0.isVisible
                }) {
                    state.apps += WorkspaceGroupBuilder.minimizedWindows(
                        onWorkspace: visible.name,
                        screenNumber: screenNumber,
                        minimized: minimizedWindows,
                        lastKnownWorkspace: lastKnownWorkspace,
                        listedWindowIDs: listedWindowIDs,
                        screenNumberOf: screenNumberOf
                    ).map { window in
                        RunningAppItem(
                            processID: window.processID,
                            name: window.title.isEmpty ? window.appName : window.title,
                            isFrontmost: false,
                            notificationBadgeCount: max(0, badgeCountByProcessID[window.processID] ?? 0),
                            windowID: window.id,
                            isMinimized: true
                        )
                    }
                }
            }

            guard showsRow else {
                return state
            }
            let showsEmpty = workspaceManager.showsEmptyWorkspaces
            state.workspaceGroups = WorkspaceGroupBuilder.groups(
                from: aeroSpaceState,
                screenNumber: screenNumber,
                includesEmpty: showsEmpty
            )
            // Empty groups are drop targets themselves, so "+" is not needed.
            state.emptyWorkspaceTarget = showsEmpty ? nil : WorkspaceGroupBuilder.emptyWorkspaceTarget(
                in: aeroSpaceState,
                screenNumber: screenNumber
            )
            return state
        }
    }

    func windowPreviews(
        for processID: pid_t,
        on displayID: CGDirectDisplayID
    ) -> [AppWindowPreviewItem] {
        windowPreviewProvider.fetchWindowPreviews(
            for: processID,
            displayID: displayID
        )
    }

    private func configureDisplayObserver() {
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleDisplayRefresh()
        }
    }

    private func configureWorkspaceObservers() {
        workspaceObservers = [
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.recordUse(of: self?.runningApplication(from: notification))
                self?.scheduleDisplayRefresh()
                // Workspace switches almost always activate another app.
                self?.workspaceManager.refresh()
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else {
                    return
                }

                if let app = self.runningApplication(from: notification) {
                    self.accessibilityObserverManager.installObserverIfNeeded(for: app)
                }
                self.scheduleDisplayRefresh()
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else {
                    return
                }

                if let app = self.runningApplication(from: notification) {
                    self.accessibilityObserverManager.removeObserver(for: app.processIdentifier)
                }
                self.scheduleDisplayRefresh()
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didHideApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleDisplayRefresh()
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didUnhideApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleDisplayRefresh()
            },
            workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleDisplayRefresh()
            }
        ]
    }

    private func teardownWorkspaceObservers() {
        for observer in workspaceObservers {
            workspaceNotificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func scheduleDisplayRefresh() {
        pendingRefreshWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.pendingRefreshWorkItem = nil
            self.refreshDisplayStates()
        }

        pendingRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + refreshDebounceInterval, execute: workItem)
    }

    private func runningApplication(from notification: Notification) -> NSRunningApplication? {
        notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    private func reopen(_ app: NSRunningApplication) {
        guard let bundleURL = app.bundleURL else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] _, _ in
            self?.refreshDisplayStates()
        }
    }

    private func refreshDisplayStates() {
        let badgeCountByProcessID = dockNotificationBadgeProvider.fetchBadgeCountByProcessID()
        displayStates = attachWorkspaces(
            to: attachPins(to: displayStateBuilder.buildDisplayStates(
                notificationBadgeCountByProcessID: badgeCountByProcessID
            )),
            badgeCountByProcessID: badgeCountByProcessID
        )
    }

    private func refreshLaunchableApplications() {
        launchableApplications = installedApplicationProvider.fetchInstalledApplications()
        seedAppUsageIfNeeded()
    }

    // MARK: Start menu

    /// Apps for the Start menu's "Frequently Used" list on one bar: the most
    /// used installed apps plus every app pinned on that bar, without the
    /// ones the user removed from the list.
    func frequentApplications(
        on displayID: CGDirectDisplayID,
        limit: Int = BarLayoutConstants.startMenuFrequentAppCount
    ) -> [LaunchableApplicationItem] {
        let pinned = displayStates.first { $0.id == displayID }?.pinnedApps ?? []
        return appUsageManager.frequentApplications(
            among: launchableApplications,
            alwaysIncludedBundleIdentifiers: Set(pinned.compactMap(\.pin.bundleIdentifier)),
            limit: limit
        )
    }

    /// Apps removed from "Frequently Used" by the user.
    var hiddenFrequentApplicationCount: Int { appUsageManager.hiddenCount }

    func hideFromFrequentApplications(bundleIdentifier: String) {
        appUsageManager.hide(bundleIdentifier: bundleIdentifier)
    }

    func restoreHiddenFrequentApplications() {
        appUsageManager.unhideAll()
    }

    /// Layout scripts for the Start menu; none without AeroSpace.
    func workspaceLayouts() -> [WorkspaceLayoutScript] {
        workspaceManager.isAvailable ? WorkspaceLayoutProvider.layouts() : []
    }

    /// Runs a layout script for the workspace shown on the given display.
    /// Beeps when the script fails.
    func runWorkspaceLayout(_ layout: WorkspaceLayoutScript, displayID: CGDirectDisplayID) {
        let workspace = PinClickRule.targetWorkspace(
            in: workspaceManager.fetchStateNow(),
            screenNumber: Self.screenNumber(of: displayID)
        )
        WorkspaceLayoutProvider.run(layout, workspace: workspace) { [weak self] succeeded in
            if !succeeded {
                NSSound.beep()
            }
            self?.workspaceManager.refresh()
        }
    }

    /// Every activation counts as one use of the app.
    private func recordUse(of app: NSRunningApplication?) {
        guard let identifier = app?.bundleIdentifier, identifier != Bundle.main.bundleIdentifier else {
            return
        }
        appUsageManager.recordUse(ofBundleIdentifier: identifier)
    }

    /// First run only: starts the list from what Spotlight knows, so it is
    /// not empty until the bar has counted for a while.
    private func seedAppUsageIfNeeded() {
        guard appUsageManager.needsSeed else {
            return
        }
        let applications = launchableApplications
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let seeds = SpotlightUsageProvider.seeds(for: applications)
            DispatchQueue.main.async {
                guard let self, self.appUsageManager.needsSeed else {
                    return
                }
                self.appUsageManager.seed(seeds)
            }
        }
    }

    private func restoreFirstMinimizedWindowIfNoVisibleWindow(of processID: pid_t) -> Bool {
        guard AXIsProcessTrusted(),
              !hasVisibleLayerZeroWindow(of: processID),
              let window = firstMinimizedWindow(of: processID) else {
            return false
        }

        let result = AXUIElementSetAttributeValue(
            window,
            AXAttributeName.minimized,
            kCFBooleanFalse
        )
        return result == .success
    }

    private func firstMinimizedWindow(of processID: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processID)
        guard let windows = AXElementInspector.windows(from: appElement) else {
            return nil
        }

        return windows.first(where: AXElementInspector.isWindowMinimized)
    }

    private func hasVisibleLayerZeroWindow(of processID: pid_t) -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        for windowInfo in windowList {
            guard let ownerPIDNumber = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
                  pid_t(ownerPIDNumber.int32Value) == processID else {
                continue
            }

            if let layerNumber = windowInfo[kCGWindowLayer as String] as? NSNumber,
               layerNumber.intValue != 0 {
                continue
            }

            if let alphaNumber = windowInfo[kCGWindowAlpha as String] as? NSNumber,
               alphaNumber.doubleValue <= 0 {
                continue
            }

            guard let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
                  let windowBounds = CGRect(dictionaryRepresentation: boundsDictionary),
                  !windowBounds.isEmpty else {
                continue
            }

            return true
        }

        return false
    }
}
