import CoreGraphics
import Foundation

enum BarLayoutConstants {
    static let panelHeight: CGFloat = 44
    static let panelCollapseAnimationDuration: TimeInterval = 0.2
    static let autoCollapsePointerPollInterval: TimeInterval = 0.08
    static let autoCollapseBottomRevealHotZoneHeight: CGFloat = 10
    static let activeWindowCheckInterval: TimeInterval = 2
    static let launcherButtonSize: CGFloat = 28
    static let launcherPopoverWidth: CGFloat = 300
    static let launcherPopoverHeight: CGFloat = 360
    static let launcherBaseFontSize: CGFloat = 11
    static let previewPanelHeight: CGFloat = 268
    static let previewPanelPadding: CGFloat = 14
    static let previewCardWidth: CGFloat = 300
    static let previewCardImageHeight: CGFloat = 172
    static let previewCardSpacing: CGFloat = 12
    static let previewPanelVerticalGap: CGFloat = 10
    static let previewPanelHorizontalInset: CGFloat = 10
    static let previewPanelShowDelay: TimeInterval = 1
    static let previewPanelHideDelay: TimeInterval = 1
    static let previewPanelFallbackWidth: CGFloat = 280
    static let pinIconSize: CGFloat = 24
    static let pinHitAreaSize: CGFloat = 30
    static let pinSpacing: CGFloat = 0
    static let pinRunningDotSize: CGFloat = 3
    /// The pin strip never takes more than this share of the bar's width;
    /// past that it scrolls sideways.
    static let pinStripMaxWidthFraction: CGFloat = 0.4
}
