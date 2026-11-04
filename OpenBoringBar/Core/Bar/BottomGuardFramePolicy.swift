import CoreGraphics

/// Decides whether the bottom guard should shrink a window so it ends above the bar.
enum BottomGuardFramePolicy {
    /// A window needs at least this much of its area on the display to be adjusted.
    /// Window managers such as AeroSpace hide windows by parking them almost entirely
    /// off-screen; those must be left alone.
    static let minimumOnScreenFraction: CGFloat = 0.5

    /// Shrinking a window below this height to clear the bar is never useful.
    static let minimumResultingHeight: CGFloat = 100

    /// Returns the frame the window should get, or `nil` when it should be left alone.
    /// Frames use top-left-origin global coordinates (Accessibility / CGDisplayBounds).
    static func adjustedFrame(
        for windowFrame: CGRect,
        displayBounds: CGRect,
        panelHeight: CGFloat
    ) -> CGRect? {
        let requiredBottomY = displayBounds.maxY - panelHeight
        guard windowFrame.maxY > requiredBottomY else {
            return nil
        }

        let windowArea = windowFrame.width * windowFrame.height
        let intersection = displayBounds.intersection(windowFrame)
        guard windowArea > 0, !intersection.isNull else {
            return nil
        }
        let onScreenFraction = (intersection.width * intersection.height) / windowArea
        guard onScreenFraction >= minimumOnScreenFraction else {
            return nil
        }

        let targetHeight = requiredBottomY - windowFrame.origin.y
        guard targetHeight >= minimumResultingHeight else {
            return nil
        }

        var adjusted = windowFrame
        adjusted.size.height = targetHeight
        return adjusted
    }
}
