import CoreGraphics

/// Detects windows that are "parked" off-screen rather than shown.
///
/// Window managers such as AeroSpace hide the windows of inactive workspaces by
/// moving them almost entirely off-screen (a 1 pt sliver stays visible in a
/// corner). macOS still reports them as on-screen, so without this rule the bar
/// shows pills for apps that only have windows on other workspaces. Window
/// cycling deliberately does not use this rule, so a pill click can reach an
/// app's windows on every workspace.
enum OffScreenWindowRule {
    /// A window with less than this share of its area on any display is parked.
    static let minimumVisibleFraction: CGFloat = 0.1

    /// `true` when less than `minimumVisibleFraction` of the window lies on the
    /// given displays combined. Frames use top-left-origin global coordinates.
    static func isParkedOffScreen(_ windowFrame: CGRect, displays: [CGRect]) -> Bool {
        let windowArea = windowFrame.width * windowFrame.height
        guard windowArea > 0 else {
            return false
        }

        let visibleArea = displays.reduce(CGFloat(0)) { total, display in
            let intersection = display.intersection(windowFrame)
            guard !intersection.isNull else {
                return total
            }
            return total + intersection.width * intersection.height
        }

        return visibleArea / windowArea < minimumVisibleFraction
    }
}
