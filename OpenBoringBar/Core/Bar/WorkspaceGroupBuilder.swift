import CoreGraphics

/// Turns an `AeroSpaceState` into the groups one display's workspace row shows.
enum WorkspaceGroupBuilder {
    /// Never offered as the "+" drop target (the two-window limit script parks
    /// displaced windows there).
    static let reservedWorkspaces: Set<String> = ["0"]

    /// Workspaces on the given screen, in keyboard order (see
    /// `keyboardOrder`). With `includesEmpty`, every workspace AeroSpace
    /// reports (its `persistent-workspaces` and any in use); otherwise only
    /// those that have windows or are visible.
    static func groups(
        from state: AeroSpaceState,
        screenNumber: Int,
        includesEmpty: Bool = false
    ) -> [WorkspaceGroup] {
        let windowsByWorkspace = Dictionary(grouping: state.windows, by: \.workspace)
        return keyboardOrder(state.workspaces).compactMap { workspace in
            guard workspace.screenNumber == screenNumber else {
                return nil
            }
            let windows = windowsByWorkspace[workspace.name] ?? []
            guard includesEmpty || !windows.isEmpty || workspace.isVisible else {
                return nil
            }
            return WorkspaceGroup(
                name: workspace.name,
                isVisible: workspace.isVisible,
                isFocused: workspace.isFocused,
                windows: windows
            )
        }
    }

    /// Workspaces as the number row of a keyboard has them: 1–9, then 0,
    /// then all other names in AeroSpace's order.
    static func keyboardOrder(_ workspaces: [AeroSpaceWorkspace]) -> [AeroSpaceWorkspace] {
        let numberRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        return workspaces.enumerated().sorted { lhs, rhs in
            let left = numberRow.firstIndex(of: lhs.element.name) ?? numberRow.count
            let right = numberRow.firstIndex(of: rhs.element.name) ?? numberRow.count
            return left != right ? left < right : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// Windows of the workspace visible on the given screen, for one pill per
    /// window: tiled windows left to right (then top to bottom) by their
    /// on-screen frame, then floating windows the same way. Windows without a
    /// known frame keep AeroSpace's order after the others in their class.
    static func visibleWorkspaceWindows(
        in state: AeroSpaceState,
        screenNumber: Int,
        frameByWindowID: [CGWindowID: CGRect]
    ) -> [AeroSpaceWindow] {
        guard let visible = state.workspaces.first(where: { $0.screenNumber == screenNumber && $0.isVisible }) else {
            return []
        }
        let windows = state.windows.enumerated().filter { $0.element.workspace == visible.name }

        return windows.sorted { lhs, rhs in
            if lhs.element.isFloating != rhs.element.isFloating {
                return !lhs.element.isFloating
            }
            switch (frameByWindowID[lhs.element.id], frameByWindowID[rhs.element.id]) {
            case let (left?, right?):
                if left.minX != right.minX { return left.minX < right.minX }
                if left.minY != right.minY { return left.minY < right.minY }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// Minimized windows to show (dimmed) on `workspace`. AeroSpace drops
    /// minimized windows from its workspaces, so each one goes to the workspace
    /// it was last seen on. A window never seen on any workspace (minimized
    /// before the bar started) goes to the visible workspace of its own screen,
    /// so it is never lost. Windows AeroSpace still lists are skipped.
    static func minimizedWindows(
        onWorkspace workspace: String,
        screenNumber: Int,
        minimized: [MinimizedWindow],
        lastKnownWorkspace: [CGWindowID: String],
        listedWindowIDs: Set<CGWindowID>,
        screenNumberOf: (MinimizedWindow) -> Int
    ) -> [MinimizedWindow] {
        minimized.filter { window in
            guard !listedWindowIDs.contains(window.id) else {
                return false
            }
            if let known = lastKnownWorkspace[window.id] {
                return known == workspace
            }
            return screenNumberOf(window) == screenNumber
        }
    }

    /// First empty, non-visible workspace on the screen: digits 1–9 first, then
    /// any other name. `nil` when none is free.
    static func emptyWorkspaceTarget(in state: AeroSpaceState, screenNumber: Int) -> String? {
        let used = Set(state.windows.map(\.workspace))
        let candidates = state.workspaces.filter {
            $0.screenNumber == screenNumber
                && !$0.isVisible
                && !used.contains($0.name)
                && !reservedWorkspaces.contains($0.name)
        }
        let digits = candidates.first { $0.name.count == 1 && $0.name.first?.isNumber == true }
        return (digits ?? candidates.first)?.name
    }
}
