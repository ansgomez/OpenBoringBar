import Foundation

/// Decides whether an empty AeroSpace read replaces the state on the bar.
/// A read that fails (timeout, AeroSpace restarting) comes back empty; the
/// last good state is kept for a short time so the bar does not blink.
enum AeroSpaceStateRetentionRule {
    /// How long the last good state survives empty reads.
    static let retention: TimeInterval = 3

    static func keepsPreviousState(
        newStateIsEmpty: Bool,
        previousStateIsEmpty: Bool,
        secondsSinceLastGoodRead: TimeInterval
    ) -> Bool {
        newStateIsEmpty && !previousStateIsEmpty && secondsSinceLastGoodRead < retention
    }
}
