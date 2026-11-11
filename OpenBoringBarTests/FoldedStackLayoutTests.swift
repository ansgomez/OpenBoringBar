import CoreGraphics
import XCTest

final class FoldedStackLayoutTests: XCTestCase {
    private let slot: CGFloat = 30

    func testStacksOnlyFromTwoIdlePins() {
        XCTAssertFalse(FoldedStackLayout.isStacked(idleCount: 1))
        XCTAssertTrue(FoldedStackLayout.isStacked(idleCount: 2))
    }

    func testIdlePinsGoToTheStackAndRunningOnesStayInline() {
        let isRunning = [false, true, false, true]
        XCTAssertEqual(FoldedStackLayout.stackedIndexes(isRunning: isRunning), [0, 2])
        XCTAssertEqual(FoldedStackLayout.inlineIndexes(isRunning: isRunning), [1, 3])
    }

    func testNoStackWithOneIdlePinOrNone() {
        XCTAssertEqual(FoldedStackLayout.stackedIndexes(isRunning: [false, true, true]), [])
        XCTAssertEqual(FoldedStackLayout.inlineIndexes(isRunning: [false, true, true]), [0, 1, 2])
        XCTAssertEqual(FoldedStackLayout.stackedIndexes(isRunning: []), [])
        XCTAssertEqual(FoldedStackLayout.inlineIndexes(isRunning: [true, true]), [0, 1])
        XCTAssertEqual(FoldedStackLayout.stackedIndexes(isRunning: [false, false]), [0, 1], "all idle")
        XCTAssertEqual(FoldedStackLayout.inlineIndexes(isRunning: [false, false]), [])
    }

    func testMoveGroupIsTheDrawnGroupOfThePin() {
        let isRunning = [false, true, false, true]
        XCTAssertEqual(FoldedStackLayout.moveGroup(isRunning: isRunning, index: 2), [0, 2])
        XCTAssertEqual(FoldedStackLayout.moveGroup(isRunning: isRunning, index: 1), [1, 3])
        XCTAssertEqual(FoldedStackLayout.moveGroup(isRunning: [false, true], index: 0), [0, 1], "no stack: all pins")
    }

    func testFoldedWidthIsMuchSmallerThanUnfolded() {
        XCTAssertEqual(FoldedStackLayout.width(count: 12, isExpanded: false, iconSlot: slot), 11 * 9 + 30)
        XCTAssertEqual(FoldedStackLayout.width(count: 12, isExpanded: true, iconSlot: slot), 12 * 30)
        XCTAssertEqual(FoldedStackLayout.width(count: 1, isExpanded: false, iconSlot: slot), 30)
        XCTAssertEqual(FoldedStackLayout.width(count: 0, isExpanded: false, iconSlot: slot), 0)
    }

    func testFoldedIconsFormRepeatingDiagonals() {
        let offsets = (0..<4).map { FoldedStackLayout.offset(index: $0, isExpanded: false, iconSlot: slot) }
        XCTAssertEqual(offsets.map(\.width), [0, 9, 18, 27])
        XCTAssertEqual(offsets.map(\.height), [-5, 0, 5, -5], "descends over three icons, then starts again")
        XCTAssertEqual((0..<3).map { FoldedStackLayout.rise(position: $0, total: 6) }, [-3, 0, 3])
    }

    func testUnfoldedIconsSitSideBySide() {
        XCTAssertEqual(
            FoldedStackLayout.offset(index: 3, isExpanded: true, iconSlot: slot),
            CGSize(width: 90, height: 0)
        )
    }

    func testOnlyUnfocusedPillsFoldAndOnlyWithAFocusedOne() {
        XCTAssertEqual(
            FoldedStackLayout.foldedFlags(isFrontmost: [false, true, false], isExpanded: false),
            [true, false, true]
        )
        XCTAssertEqual(
            FoldedStackLayout.foldedFlags(isFrontmost: [false, true, false], isExpanded: true),
            [false, false, false]
        )
        XCTAssertEqual(
            FoldedStackLayout.foldedFlags(isFrontmost: [false, false], isExpanded: false),
            [false, false],
            "no focused window in the row: every title stays readable"
        )
    }

    func testRunPositionsRestartAfterAnUnfoldedItem() {
        XCTAssertEqual(
            FoldedStackLayout.runPositions(isFolded: [true, true, false, true, true, true]),
            [0, 1, nil, 0, 1, 2]
        )
        XCTAssertEqual(FoldedStackLayout.runPositions(isFolded: [false, false]), [nil, nil])
        XCTAssertEqual(FoldedStackLayout.runPositions(isFolded: []), [])
    }
}
