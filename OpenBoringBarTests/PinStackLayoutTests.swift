import CoreGraphics
import XCTest

final class PinStackLayoutTests: XCTestCase {
    private let slot: CGFloat = 30

    func testStacksOnlyFromTwoIdlePins() {
        XCTAssertFalse(PinStackLayout.isStacked(idleCount: 1))
        XCTAssertTrue(PinStackLayout.isStacked(idleCount: 2))
    }

    func testFoldedWidthIsMuchSmallerThanUnfolded() {
        XCTAssertEqual(PinStackLayout.width(count: 12, isExpanded: false, iconSlot: slot), 11 * 9 + 30)
        XCTAssertEqual(PinStackLayout.width(count: 12, isExpanded: true, iconSlot: slot), 12 * 30)
        XCTAssertEqual(PinStackLayout.width(count: 0, isExpanded: false, iconSlot: slot), 0)
    }

    func testFoldedIconsFormRepeatingDiagonals() {
        let offsets = (0..<4).map { PinStackLayout.offset(index: $0, isExpanded: false, iconSlot: slot) }
        XCTAssertEqual(offsets.map(\.width), [0, 9, 18, 27])
        XCTAssertEqual(offsets.map(\.height), [-5, 0, 5, -5], "rises over three icons, then starts again")
    }

    func testRunPositionsRestartAfterAnUnfoldedItem() {
        XCTAssertEqual(
            PinStackLayout.runPositions(isFolded: [true, true, false, true, true, true]),
            [0, 1, nil, 0, 1, 2]
        )
        XCTAssertEqual(PinStackLayout.runPositions(isFolded: [false, false]), [nil, nil])
    }

    func testUnfoldedIconsSitSideBySide() {
        XCTAssertEqual(
            PinStackLayout.offset(index: 3, isExpanded: true, iconSlot: slot),
            CGSize(width: 90, height: 0)
        )
    }
}
