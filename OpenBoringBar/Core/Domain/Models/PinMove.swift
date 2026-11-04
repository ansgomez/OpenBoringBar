import Foundation

/// A reorder action from a pinned icon's menu.
enum PinMove: CaseIterable {
    case left
    case right
    case toStart
    case toEnd

    var menuTitle: String {
        switch self {
        case .left:
            return "Move Left"
        case .right:
            return "Move Right"
        case .toStart:
            return "Move to Start"
        case .toEnd:
            return "Move to End"
        }
    }

    var systemImageName: String {
        switch self {
        case .left:
            return "arrow.left"
        case .right:
            return "arrow.right"
        case .toStart:
            return "arrow.left.to.line"
        case .toEnd:
            return "arrow.right.to.line"
        }
    }
}
