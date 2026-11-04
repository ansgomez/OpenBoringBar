import Foundation

/// Which bars show pins.
enum PinDisplayMode: String, Codable, CaseIterable {
    /// Every bar shows the shared list.
    case allDisplays
    /// Only the main display's bar shows the shared list.
    case mainDisplayOnly
    /// Each display has its own list, keyed by display UUID.
    case perDisplay

    var menuTitle: String {
        switch self {
        case .allDisplays:
            return "All Displays"
        case .mainDisplayOnly:
            return "Main Display Only"
        case .perDisplay:
            return "Each Display Separately"
        }
    }
}
