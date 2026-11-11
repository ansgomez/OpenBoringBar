import CoreGraphics
import Foundation

/// Keeps a current `AeroSpaceState` for the workspace row and runs workspace
/// commands. AeroSpace does not push changes, so state is re-read on demand
/// (`refresh()`), after each command, and on a fallback timer.
final class AeroSpaceWorkspaceManager {
    private static let showsWorkspacesDefaultsKey = "OpenBoringBar.showWorkspaces"
    private static let pillsFollowWorkspaceDefaultsKey = "OpenBoringBar.pillsFollowWorkspace"
    private static let showsEmptyWorkspacesDefaultsKey = "OpenBoringBar.showEmptyWorkspaces"
    static let pollInterval: TimeInterval = 2
    /// Wait after a command before re-reading, so AeroSpace has applied it.
    private static let postCommandRefreshDelay: TimeInterval = 0.15
    /// Minimum spacing of throttled refreshes. Window events (moves, title
    /// changes) can fire many times per second, e.g. a terminal whose title
    /// animates; each fetch runs the CLI three times.
    static let throttledRefreshInterval: TimeInterval = 1
    /// How long `focusNewWindow` waits for the window to show up.
    private static let newWindowPollInterval: TimeInterval = 0.1
    private static let newWindowPollCount = 20

    private let client: AeroSpaceControlling
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.openboringbar.aerospace", qos: .userInitiated)
    private var pollTimer: Timer?
    private var isFetching = false
    private var needsAnotherFetch = false
    private var lastFetchStart: TimeInterval = -.infinity
    private var throttledRefreshWorkItem: DispatchWorkItem?

    /// Called on the main thread whenever `state` changes.
    var onStateChanged: (() -> Void)?

    private(set) var state: AeroSpaceState = .empty {
        didSet { lastKnownWorkspaceByWindowID.merge(state.workspaceByWindowID) { $1 } }
    }
    /// Last workspace each window was seen on. Kept after the window leaves
    /// AeroSpace's list (for example when minimized), so it can be shown and
    /// restored on that workspace.
    private(set) var lastKnownWorkspaceByWindowID: [CGWindowID: String] = [:]
    /// Uptime of the last read that returned workspaces.
    private var lastGoodFetch: TimeInterval = -.infinity
    private(set) var showsWorkspaces: Bool
    /// One pill per window of the visible workspace, instead of one per app.
    private(set) var pillsFollowWorkspace: Bool
    /// The row also shows workspaces without windows.
    private(set) var showsEmptyWorkspaces: Bool

    init(client: AeroSpaceControlling = AeroSpaceClient(), defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        self.showsWorkspaces = defaults.object(forKey: Self.showsWorkspacesDefaultsKey) as? Bool ?? true
        self.pillsFollowWorkspace = defaults.object(forKey: Self.pillsFollowWorkspaceDefaultsKey) as? Bool ?? true
        self.showsEmptyWorkspaces = defaults.object(forKey: Self.showsEmptyWorkspacesDefaultsKey) as? Bool ?? false
    }

    deinit {
        pollTimer?.invalidate()
        throttledRefreshWorkItem?.cancel()
    }

    var isAvailable: Bool { client.isAvailable }

    /// Whether bars draw the workspace row.
    var isRowVisible: Bool { isAvailable && showsWorkspaces }

    /// Whether pills currently come from AeroSpace (needs a first state read).
    var isPillsFollowingWorkspace: Bool {
        isAvailable && pillsFollowWorkspace && !state.workspaces.isEmpty
    }

    func setPillsFollowWorkspace(_ isEnabled: Bool) {
        guard pillsFollowWorkspace != isEnabled else {
            return
        }
        pillsFollowWorkspace = isEnabled
        defaults.set(isEnabled, forKey: Self.pillsFollowWorkspaceDefaultsKey)
        onStateChanged?()
    }

    func setShowsEmptyWorkspaces(_ isEnabled: Bool) {
        guard showsEmptyWorkspaces != isEnabled else {
            return
        }
        showsEmptyWorkspaces = isEnabled
        defaults.set(isEnabled, forKey: Self.showsEmptyWorkspacesDefaultsKey)
        onStateChanged?()
    }

    func start() {
        guard isAvailable, pollTimer == nil else {
            return
        }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        refresh()
    }

    func setShowsWorkspaces(_ isEnabled: Bool) {
        guard showsWorkspaces != isEnabled else {
            return
        }
        showsWorkspaces = isEnabled
        defaults.set(isEnabled, forKey: Self.showsWorkspacesDefaultsKey)
        onStateChanged?()
    }

    /// Like `refresh()`, but at most once per `throttledRefreshInterval`;
    /// requests inside the interval collapse into one trailing refresh.
    func refreshThrottled() {
        guard isAvailable, throttledRefreshWorkItem == nil else {
            return
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - lastFetchStart
        guard elapsed < Self.throttledRefreshInterval else {
            refresh()
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.throttledRefreshWorkItem = nil
            self?.refresh()
        }
        throttledRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (Self.throttledRefreshInterval - elapsed),
            execute: workItem
        )
    }

    /// Re-reads AeroSpace in the background; overlapping requests are coalesced.
    func refresh() {
        guard isAvailable else {
            return
        }
        guard !isFetching else {
            needsAnotherFetch = true
            return
        }
        isFetching = true
        lastFetchStart = ProcessInfo.processInfo.systemUptime

        queue.async { [weak self] in
            guard let self else {
                return
            }
            let newState = self.client.fetchState()
            DispatchQueue.main.async {
                self.isFetching = false
                let now = ProcessInfo.processInfo.systemUptime
                if !newState.workspaces.isEmpty {
                    self.lastGoodFetch = now
                }
                let isTransientFailure = AeroSpaceStateRetentionRule.keepsPreviousState(
                    newStateIsEmpty: newState.workspaces.isEmpty,
                    previousStateIsEmpty: self.state.workspaces.isEmpty,
                    secondsSinceLastGoodRead: now - self.lastGoodFetch
                )
                if !isTransientFailure, newState != self.state {
                    self.state = newState
                    self.onStateChanged?()
                }
                if self.needsAnotherFetch {
                    self.needsAnotherFetch = false
                    self.refresh()
                }
            }
        }
    }

    /// Reads AeroSpace now, on the calling thread (used when a menu opens).
    func fetchStateNow() -> AeroSpaceState {
        guard isAvailable else {
            return .empty
        }
        let fresh = client.fetchState()
        lastKnownWorkspaceByWindowID.merge(fresh.workspaceByWindowID) { $1 }
        return fresh
    }

    func moveWindow(_ windowID: CGWindowID, toWorkspace workspace: String) {
        perform { $0.moveWindow(windowID, toWorkspace: workspace) }
    }

    func focusWindow(_ windowID: CGWindowID) {
        perform { $0.focusWindow(windowID) }
    }

    func switchToWorkspace(_ workspace: String) {
        perform { $0.switchToWorkspace(workspace) }
    }

    /// Waits (up to 2 s) for a window of the process that is not in
    /// `knownWindowIDs`, moves it to `workspace` if AeroSpace put it elsewhere,
    /// and focuses it. `completion` runs on the main thread with `false` when
    /// no window appeared.
    func focusNewWindow(
        ofProcessID processID: pid_t,
        knownWindowIDs: Set<CGWindowID>,
        onWorkspace workspace: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard isAvailable else {
            completion(false)
            return
        }
        queue.async { [weak self] in
            guard let self else {
                return
            }
            var didFocus = false
            for _ in 0..<Self.newWindowPollCount {
                let newWindow = self.client.fetchState().windows.first {
                    $0.processID == processID && !knownWindowIDs.contains($0.id)
                }
                if let newWindow {
                    if newWindow.workspace != workspace {
                        self.client.moveWindow(newWindow.id, toWorkspace: workspace)
                    }
                    self.client.focusWindow(newWindow.id)
                    didFocus = true
                    break
                }
                Thread.sleep(forTimeInterval: Self.newWindowPollInterval)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.postCommandRefreshDelay) {
                completion(didFocus)
                self.refresh()
            }
        }
    }

    private func perform(_ command: @escaping (AeroSpaceControlling) -> Void) {
        guard isAvailable else {
            return
        }
        queue.async { [weak self] in
            guard let self else {
                return
            }
            command(self.client)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.postCommandRefreshDelay) {
                self.refresh()
            }
        }
    }
}
