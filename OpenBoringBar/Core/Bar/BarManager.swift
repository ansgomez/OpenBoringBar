import AppKit
import ApplicationServices
import Combine

final class BarManager: ObservableObject {
    @Published private(set) var displayStates: [DisplayState]
    @Published private(set) var launchableApplications: [LaunchableApplicationItem]

    private let eventBus: AppEventBus
    private let installedApplicationProvider: InstalledApplicationProviding
    private let windowPreviewProvider: WindowPreviewProviding
    private let windowWorkspaceProvider: WindowWorkspaceProviding
    private let dockNotificationBadgeProvider: DockNotificationBadgeProviding
    private let displayStateBuilder: BarDisplayStateBuilder
    private let accessibilityObserverManager: BarAccessibilityObserverManager
    private let pinnedAppManager: PinnedAppManager
    private let workspaceNotificationCenter: NotificationCenter

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
        windowWorkspaceProvider: WindowWorkspaceProviding = WindowWorkspaceProvider(),
        dockNotificationBadgeProvider: DockNotificationBadgeProviding = DockNotificationBadgeProvider(),
        displayStateBuilder: BarDisplayStateBuilder = BarDisplayStateBuilder(),
        accessibilityObserverManager: BarAccessibilityObserverManager = BarAccessibilityObserverManager(),
        pinnedAppManager: PinnedAppManager = PinnedAppManager(
            storage: PinnedAppStorageProvider(),
            locator: ApplicationLocationProvider()
        )
    ) {
        self.displayStates = []
        self.launchableApplications = []
        self.eventBus = eventBus
        self.installedApplicationProvider = installedApplicationProvider
        self.windowPreviewProvider = windowPreviewProvider
        self.windowWorkspaceProvider = windowWorkspaceProvider
        self.dockNotificationBadgeProvider = dockNotificationBadgeProvider
        self.displayStateBuilder = displayStateBuilder
        self.accessibilityObserverManager = accessibilityObserverManager
        self.pinnedAppManager = pinnedAppManager
        self.workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        self.workspaceObservers = []
        self.hidesOffScreenWindows = UserDefaults.standard.object(
            forKey: Self.hidesOffScreenWindowsDefaultsKey
        ) as? Bool ?? true
        self.displayStateBuilder.hidesOffScreenWindows = hidesOffScreenWindows

        self.accessibilityObserverManager.onObservedChange = { [weak self] in
            self?.scheduleDisplayRefresh()
        }
        self.dockNotificationBadgeProvider.onBadgeStateChanged = { [weak self] in
            self?.scheduleDisplayRefresh()
        }

        configureDisplayObserver()
        configureWorkspaceObservers()
        self.accessibilityObserverManager.installObserversForRunningApps()
        self.dockNotificationBadgeProvider.startObserving()

        refreshDisplayStates()
        refreshLaunchableApplications()
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

    /// Pin click: always goes through `openApplication`, which launches the
    /// app, or brings it forward and opens a window if it has none (like the
    /// Dock). Never minimizes.
    func openPinnedApp(_ item: PinnedAppItem) {
        guard let url = pinnedAppManager.resolvedURL(for: item.pin) else {
            NSLog("OpenBoringBar: pinned app not found: \(item.pin.bundleIdentifier ?? item.pin.bundleURL.path)")
            NSSound.beep()
            scheduleDisplayRefresh()
            return
        }
        openApplication(bundleURL: url)
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
        let runningApps = NSWorkspace.shared.runningApplications.map {
            RunningAppDescriptor(bundleIdentifier: $0.bundleIdentifier, bundleURL: $0.bundleURL)
        }

        return states.map { state in
            var state = state
            let context = pinContext(for: state.id)
            state.displayUUID = context.displayUUID
            state.isMainDisplay = context.isMainDisplay
            state.canEditPins = pinnedAppManager.canEditPins(isMainDisplay: context.isMainDisplay)
            state.pinnedApps = pinnedAppManager
                .pins(forDisplayUUID: context.displayUUID, isMainDisplay: context.isMainDisplay)
                .compactMap { pin in
                    // Pins that cannot be found are kept but not drawn.
                    guard let url = pinnedAppManager.resolvedURL(for: pin) else {
                        return nil
                    }
                    return PinnedAppItem(
                        pin: pin,
                        resolvedURL: url,
                        name: Self.displayName(ofApplicationAt: url),
                        isRunning: PinnedAppMatcher.isRunning(pin, resolvedURL: url, among: runningApps)
                    )
                }
            return state
        }
    }

    private static func displayName(ofApplicationAt url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
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

    /// AeroSpace workspace of each window, if AeroSpace is installed.
    func windowWorkspaces() -> WindowWorkspaceSnapshot {
        windowWorkspaceProvider.fetchSnapshot()
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
            ) { [weak self] _ in
                self?.scheduleDisplayRefresh()
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
        displayStates = attachPins(to: displayStateBuilder.buildDisplayStates(
            notificationBadgeCountByProcessID: badgeCountByProcessID
        ))
    }

    private func refreshLaunchableApplications() {
        launchableApplications = installedApplicationProvider.fetchInstalledApplications()
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
