import CoreGraphics

/// Geometry of the stack of idle pins (pinned apps that are not running).
/// Folded, the icons overlap in short diagonals, like a pile of record
/// sleeves: each one a step to the right, rising over `diagonalLength` icons,
/// then starting again. Unfolded (pointer over the stack) they sit side by
/// side like normal pins.
enum PinStackLayout {
    /// Fewer idle pins than this are drawn as normal pins.
    static let minimumCount = 2
    /// Horizontal distance between neighbours when folded.
    static let foldedStep: CGFloat = 9
    /// Icons per diagonal.
    static let diagonalLength = 3
    /// Height difference between the first and the last icon of a diagonal.
    static let diagonalRise: CGFloat = 10

    static func isStacked(idleCount: Int) -> Bool {
        idleCount >= minimumCount
    }

    /// Offset of the icon at `index` from the stack's leading edge and
    /// vertical center. Positive `height` is down: a diagonal starts high at
    /// the back and ends low at the front.
    static func offset(index: Int, isExpanded: Bool, iconSlot: CGFloat) -> CGSize {
        guard !isExpanded else {
            return CGSize(width: CGFloat(index) * iconSlot, height: 0)
        }
        return CGSize(width: CGFloat(index) * foldedStep, height: rise(position: index, total: diagonalRise))
    }

    /// Vertical offset of the icon at `position` in a run of folded icons,
    /// for a diagonal that spans `total` points.
    static func rise(position: Int, total: CGFloat) -> CGFloat {
        total * (CGFloat(position % diagonalLength) / CGFloat(diagonalLength - 1) - 0.5)
    }

    /// For a row where only some items are folded: each folded item's
    /// position within its run of folded neighbours (0 for the first), `nil`
    /// for items that are not folded.
    static func runPositions(isFolded: [Bool]) -> [Int?] {
        var position = 0
        return isFolded.map { folded in
            guard folded else {
                position = 0
                return nil
            }
            defer { position += 1 }
            return position
        }
    }

    static func width(count: Int, isExpanded: Bool, iconSlot: CGFloat) -> CGFloat {
        guard count > 0 else {
            return 0
        }
        let step = isExpanded ? iconSlot : foldedStep
        return CGFloat(count - 1) * step + iconSlot
    }
}
