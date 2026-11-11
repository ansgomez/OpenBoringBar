import XCTest

final class AeroSpaceStateRetentionRuleTests: XCTestCase {
    private func keeps(new: Bool, previous: Bool, after seconds: TimeInterval) -> Bool {
        AeroSpaceStateRetentionRule.keepsPreviousState(
            newStateIsEmpty: new,
            previousStateIsEmpty: previous,
            secondsSinceLastGoodRead: seconds
        )
    }

    func testEmptyReadIsIgnoredOnlyForAShortTime() {
        XCTAssertTrue(keeps(new: true, previous: false, after: 0.5))
        XCTAssertFalse(keeps(new: true, previous: false, after: 3), "AeroSpace is gone: clear the groups")
    }

    func testGoodReadsAndAlreadyEmptyStateAreNeverHeldBack() {
        XCTAssertFalse(keeps(new: false, previous: false, after: 0.5))
        XCTAssertFalse(keeps(new: true, previous: true, after: 0.5))
    }
}
