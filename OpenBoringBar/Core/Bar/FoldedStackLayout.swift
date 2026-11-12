import CoreGraphics
import Foundation

/// Rules and geometry for the bar's folded stacks: idle pins (pinned apps
/// that are not running) and the pills of unfocused windows.
///
/// Folded, the items overlap in short diagonals, like a pile of record
/// sleeves: each one a step to the right, descending over `diagonalLength`
/// items, then starting again. Unfolded (pointer over the stack) they sit
/// side by side.
enum FoldedStackLayout {
    /// Fewer idle pins than this are drawn as normal pins.
    static let minimumCount = 2
    /// Horizontal distance between neighbouring pins when folded.
    static let foldedStep: CGFloat = 9
    /// Items per diagonal (at least 2).
    static let diagonalLength = 3
    /// Height difference between the first and the last pin of a diagonal.
    static let pinRise: CGFloat = 8
    /// How far a folded pill reaches over the folded pill before it.
    static let pillOverlap: CGFloat = 15
    /// Height difference within a diagonal of folded pills.
    static let pillRise: CGFloat = 6
    /// The pointer must rest on a stack this long before it unfolds, so
    /// passing over it does not move the bar.
    static let hoverIntentDelay: TimeInterval = 0.13

    // MARK: Pins

    static func isStacked(idleCount: Int) -> Bool {
        idleCount >= minimumCount
    }

    /// Indexes of the pins drawn in the stack: the idle ones, when there are
    /// enough of them; else none.
    static func stackedIndexes(isRunning: [Bool]) -> [Int] {
        let idle = isRunning.indices.filter { !isRunning[$0] }
        return isStacked(idleCount: idle.count) ? idle : []
    }

    /// Indexes of the pins drawn at full size, in order: the running ones
    /// when there is a stack, else all.
    static func inlineIndexes(isRunning: [Bool]) -> [Int] {
        stackedIndexes(isRunning: isRunning).isEmpty
            ? Array(isRunning.indices)
            : isRunning.indices.filter { isRunning[$0] }
    }

    /// The pins drawn next to the pin at `index`, in drawn order: the stack
    /// or the full-size pins. Move Left/Right act within this group, so a
    /// move always changes what is drawn.
    static func moveGroup(isRunning: [Bool], index: Int) -> [Int] {
        let stacked = stackedIndexes(isRunning: isRunning)
        return stacked.contains(index) ? stacked : inlineIndexes(isRunning: isRunning)
    }

    /// Offset of the pin at `index` in the stack from the stack's leading
    /// edge and vertical center. Positive `height` is down: a diagonal
    /// starts high at the back and ends low at the front.
    static func offset(index: Int, isExpanded: Bool, iconSlot: CGFloat) -> CGSize {
        guard !isExpanded else {
            return CGSize(width: CGFloat(index) * iconSlot, height: 0)
        }
        return CGSize(width: CGFloat(index) * foldedStep, height: rise(position: index, total: pinRise))
    }

    static func width(count: Int, isExpanded: Bool, iconSlot: CGFloat) -> CGFloat {
        guard count > 0 else {
            return 0
        }
        let step = isExpanded ? iconSlot : foldedStep
        return CGFloat(count - 1) * step + iconSlot
    }

    // MARK: Shared

    /// Vertical offset of the item at `position` in a run of folded items,
    /// for a diagonal that spans `total` points.
    static func rise(position: Int, total: CGFloat) -> CGFloat {
        let length = max(2, diagonalLength)
        return total * (CGFloat(position % length) / CGFloat(length - 1) - 0.5)
    }

    // MARK: Pills

    /// Which pills are folded: every unfocused one, but only while some
    /// window of the row is focused (else no title would be readable) and
    /// the row is not unfolded.
    static func foldedFlags(isFrontmost: [Bool], isExpanded: Bool) -> [Bool] {
        guard !isExpanded, isFrontmost.contains(true) else {
            return isFrontmost.map { _ in false }
        }
        return isFrontmost.map { !$0 }
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
}
