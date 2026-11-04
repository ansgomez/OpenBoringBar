import CoreGraphics
import XCTest

final class BottomGuardFramePolicyTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let panelHeight: CGFloat = 44

    func testWindowAboveBarIsLeftAlone() {
        let frame = CGRect(x: 0, y: 33, width: 756, height: 896)
        XCTAssertNil(BottomGuardFramePolicy.adjustedFrame(for: frame, displayBounds: display, panelHeight: panelHeight))
    }

    func testWindowOverlappingBarIsShrunkKeepingTop() {
        let frame = CGRect(x: 10, y: 33, width: 756, height: 949)
        let adjusted = BottomGuardFramePolicy.adjustedFrame(for: frame, displayBounds: display, panelHeight: panelHeight)
        XCTAssertEqual(adjusted, CGRect(x: 10, y: 33, width: 756, height: 982 - 44 - 33))
    }

    func testWindowParkedOffScreenByWindowManagerIsLeftAlone() {
        // AeroSpace hides windows of inactive workspaces in the bottom-right corner.
        let frame = CGRect(x: 1511, y: 950, width: 1512, height: 896)
        XCTAssertNil(BottomGuardFramePolicy.adjustedFrame(for: frame, displayBounds: display, panelHeight: panelHeight))
    }

    func testWindowStartingUnderBarIsLeftAlone() {
        let frame = CGRect(x: 100, y: 900, width: 400, height: 60)
        XCTAssertNil(BottomGuardFramePolicy.adjustedFrame(for: frame, displayBounds: display, panelHeight: panelHeight))
    }

    func testDisplayWithOffsetOriginUsesItsOwnBottom() {
        let secondDisplay = CGRect(x: 1512, y: -200, width: 1920, height: 1080)
        let frame = CGRect(x: 1600, y: 0, width: 800, height: 880)
        let adjusted = BottomGuardFramePolicy.adjustedFrame(for: frame, displayBounds: secondDisplay, panelHeight: panelHeight)
        XCTAssertEqual(adjusted?.maxY, 880 - 44)
    }
}
