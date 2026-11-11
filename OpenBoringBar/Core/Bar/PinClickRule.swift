import CoreGraphics
import Foundation

/// Decides what a pin click does for a running app, so that the click never
/// leaves the workspace shown on the clicked bar: it focuses the app's window
/// there, or asks for a new window when the app has none there.
enum PinClickRule {
    /// The workspace shown on the given screen, else the focused one.
    static func targetWorkspace(in state: AeroSpaceState, screenNumber: Int?) -> String? {
        let visibleOnScreen = state.workspaces.first {
            $0.isVisible && screenNumber != nil && $0.screenNumber == screenNumber
        }
        return visibleOnScreen?.name ?? state.focusedWorkspace
    }

    /// With several windows on the workspace, repeated clicks step through
    /// them: the window after the focused one is next.
    static func action(
        in state: AeroSpaceState,
        screenNumber: Int?,
        processID: pid_t,
        forcesNewWindow: Bool
    ) -> PinClickAction {
        let workspace = targetWorkspace(in: state, screenNumber: screenNumber)
        guard !forcesNewWindow else {
            return .openNewWindow(workspace: workspace)
        }
        guard let workspace else {
            return .activate
        }

        let windowsHere = state.windows.filter {
            $0.processID == processID && $0.workspace == workspace
        }
        guard let first = windowsHere.first else {
            return .openNewWindow(workspace: workspace)
        }
        guard let focusedIndex = windowsHere.firstIndex(where: { $0.id == state.focusedWindowID }) else {
            return .focusWindow(first.id)
        }
        return .focusWindow(windowsHere[(focusedIndex + 1) % windowsHere.count].id)
    }
}
