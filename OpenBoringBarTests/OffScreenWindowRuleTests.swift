import CoreGraphics
import XCTest

final class OffScreenWindowRuleTests: XCTestCase {
    private let builtIn = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let external = CGRect(x: 1512, y: 0, width: 1920, height: 1080)

    func testNormalWindowIsNotParked() {
        let frame = CGRect(x: 0, y: 33, width: 756, height: 896)
        XCTAssertFalse(OffScreenWindowRule.isParkedOffScreen(frame, displays: [builtIn]))
    }

    func testAeroSpaceCornerWindowIsParked() {
        let frame = CGRect(x: 1511, y: 950, width: 1512, height: 896)
        XCTAssertTrue(OffScreenWindowRule.isParkedOffScreen(frame, displays: [builtIn]))
    }

    func testWindowSpanningTwoDisplaysIsNotParked() {
        let frame = CGRect(x: 1200, y: 100, width: 800, height: 600)
        XCTAssertFalse(OffScreenWindowRule.isParkedOffScreen(frame, displays: [builtIn, external]))
    }

    func testWindowPartlyDraggedOffScreenIsNotParked() {
        let frame = CGRect(x: 1100, y: 100, width: 800, height: 600)
        XCTAssertFalse(OffScreenWindowRule.isParkedOffScreen(frame, displays: [builtIn]))
    }

    func testEmptyFrameIsNotParked() {
        XCTAssertFalse(OffScreenWindowRule.isParkedOffScreen(.zero, displays: [builtIn]))
    }
}
