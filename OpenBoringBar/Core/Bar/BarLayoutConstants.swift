import CoreGraphics
import Foundation

enum BarLayoutConstants {
    static let panelHeight: CGFloat = 44
    static let workspaceGroupHeight: CGFloat = 28
    /// Height of the group of the workspace on screen, which holds the pills.
    static let workspaceExpandedGroupHeight: CGFloat = 38
    static let workspaceGroupSpacing: CGFloat = 6
    static let workspaceIconSize: CGFloat = 18
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
    /// Apps listed under "Frequently Used" in the Start menu.
    static let startMenuFrequentAppCount = 10
    static let startButtonSymbolSize: CGFloat = 15
    static let pinHitAreaSize: CGFloat = 30
    static let pinSpacing: CGFloat = 0
    /// Gap between pin rows, if a strip is given more than one row.
    static let pinRowSpacing: CGFloat = 4
    static let statWidgetSpacing: CGFloat = 2
    static let statWidgetRowSpacing: CGFloat = 2
    static let statWidgetHeight: CGFloat = 18
    static let pinRunningDotSize: CGFloat = 3
    /// The pin strip never takes more than this share of the bar's width;
    /// past that it scrolls sideways.
    static let pinStripMaxWidthFraction: CGFloat = 0.4
}
