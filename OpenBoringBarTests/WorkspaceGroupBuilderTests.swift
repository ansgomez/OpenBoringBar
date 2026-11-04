import CoreGraphics
import XCTest

final class WorkspaceGroupBuilderTests: XCTestCase {
    private func workspace(_ name: String, screen: Int = 1, visible: Bool = false, focused: Bool = false) -> AeroSpaceWorkspace {
        AeroSpaceWorkspace(name: name, screenNumber: screen, isVisible: visible, isFocused: focused)
    }

    private func window(_ id: UInt32, on workspace: String, layout: String = "h_tiles") -> AeroSpaceWindow {
        AeroSpaceWindow(
            id: id, workspace: workspace, processID: 1, bundleIdentifier: nil,
            appName: "App", layout: layout, title: ""
        )
    }

    func testVisibleWorkspaceWindowsSortTiledByPositionThenFloating() {
        let state = AeroSpaceState(
            workspaces: [workspace("A"), workspace("W", visible: true, focused: true)],
            windows: [
                window(1, on: "W", layout: "floating"),
                window(2, on: "W"),
                window(3, on: "A"),
                window(4, on: "W"),
                window(5, on: "W")
            ]
        )
        let frames: [CGWindowID: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 100, height: 100),
            2: CGRect(x: 756, y: 33, width: 756, height: 864),
            4: CGRect(x: 0, y: 33, width: 756, height: 864)
        ]
        let windows = WorkspaceGroupBuilder.visibleWorkspaceWindows(in: state, screenNumber: 1, frameByWindowID: frames)
        XCTAssertEqual(windows.map(\.id), [4, 2, 5, 1], "tiled left-to-right, unknown frame after, floating last")
    }

    func testVisibleWorkspaceWindowsEmptyWithoutVisibleWorkspace() {
        let state = AeroSpaceState(workspaces: [workspace("A", screen: 2, visible: true)], windows: [window(1, on: "A")])
        XCTAssertTrue(WorkspaceGroupBuilder.visibleWorkspaceWindows(in: state, screenNumber: 1, frameByWindowID: [:]).isEmpty)
    }

    func testShowsNonEmptyAndVisibleWorkspacesInOrder() {
        let state = AeroSpaceState(
            workspaces: [workspace("0"), workspace("1"), workspace("2"), workspace("A"), workspace("W", visible: true, focused: true)],
            windows: [window(1, on: "2"), window(2, on: "A"), window(3, on: "A")]
        )
        let groups = WorkspaceGroupBuilder.groups(from: state, screenNumber: 1)
        XCTAssertEqual(groups.map(\.name), ["2", "A", "W"])
        XCTAssertEqual(groups[1].windows.map(\.id), [2, 3])
        XCTAssertTrue(groups[2].isFocused)
        XCTAssertTrue(groups[2].windows.isEmpty)
    }

    func testOnlyWorkspacesOfTheScreen() {
        let state = AeroSpaceState(
            workspaces: [workspace("1", screen: 1), workspace("S", screen: 2, visible: true)],
            windows: [window(1, on: "1"), window(2, on: "S")]
        )
        XCTAssertEqual(WorkspaceGroupBuilder.groups(from: state, screenNumber: 2).map(\.name), ["S"])
    }

    func testEmptyTargetPrefersDigitsAndSkipsReservedAndVisible() {
        let state = AeroSpaceState(
            workspaces: [workspace("0"), workspace("1"), workspace("2"), workspace("3", visible: true), workspace("A")],
            windows: [window(1, on: "1")]
        )
        XCTAssertEqual(WorkspaceGroupBuilder.emptyWorkspaceTarget(in: state, screenNumber: 1), "2")
    }

    func testEmptyTargetFallsBackToLettersThenNil() {
        let lettersOnly = AeroSpaceState(
            workspaces: [workspace("0"), workspace("1"), workspace("B")],
            windows: [window(1, on: "1")]
        )
        XCTAssertEqual(WorkspaceGroupBuilder.emptyWorkspaceTarget(in: lettersOnly, screenNumber: 1), "B")

        let full = AeroSpaceState(workspaces: [workspace("0"), workspace("1")], windows: [window(1, on: "1")])
        XCTAssertNil(WorkspaceGroupBuilder.emptyWorkspaceTarget(in: full, screenNumber: 1))
    }
}
