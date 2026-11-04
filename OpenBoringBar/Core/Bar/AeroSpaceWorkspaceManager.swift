import CoreGraphics
import Foundation

/// Keeps a current `AeroSpaceState` for the workspace row and runs workspace
/// commands. AeroSpace does not push changes, so state is re-read on demand
/// (`refresh()`), after each command, and on a fallback timer.
final class AeroSpaceWorkspaceManager {
    private static let showsWorkspacesDefaultsKey = "OpenBoringBar.showWorkspaces"
    private static let pillsFollowWorkspaceDefaultsKey = "OpenBoringBar.pillsFollowWorkspace"
    static let pollInterval: TimeInterval = 2
    /// Wait after a command before re-reading, so AeroSpace has applied it.
    private static let postCommandRefreshDelay: TimeInterval = 0.15
    /// Minimum spacing of throttled refreshes. Window events (moves, title
    /// changes) can fire many times per second, e.g. a terminal whose title
    /// animates; each fetch runs the CLI three times.
    static let throttledRefreshInterval: TimeInterval = 1

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

    private(set) var state: AeroSpaceState = .empty
    private(set) var showsWorkspaces: Bool
    /// One pill per window of the visible workspace, instead of one per app.
    private(set) var pillsFollowWorkspace: Bool

    init(client: AeroSpaceControlling = AeroSpaceClient(), defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        self.showsWorkspaces = defaults.object(forKey: Self.showsWorkspacesDefaultsKey) as? Bool ?? true
        self.pillsFollowWorkspace = defaults.object(forKey: Self.pillsFollowWorkspaceDefaultsKey) as? Bool ?? true
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
                if newState != self.state {
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
        isAvailable ? client.fetchState() : .empty
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
