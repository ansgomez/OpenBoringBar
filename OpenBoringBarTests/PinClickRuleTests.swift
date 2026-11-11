import CoreGraphics
import XCTest

final class PinClickRuleTests: XCTestCase {
    private func workspace(_ name: String, screen: Int = 1, visible: Bool = false, focused: Bool = false) -> AeroSpaceWorkspace {
        AeroSpaceWorkspace(name: name, screenNumber: screen, isVisible: visible, isFocused: focused)
    }

    private func window(_ id: UInt32, on workspace: String, pid: pid_t = 1) -> AeroSpaceWindow {
        AeroSpaceWindow(
            id: id, workspace: workspace, processID: pid, bundleIdentifier: nil,
            appName: "App", layout: "h_tiles", title: ""
        )
    }

    private func action(_ state: AeroSpaceState, screen: Int? = 1, forcesNewWindow: Bool = false) -> PinClickAction {
        PinClickRule.action(in: state, screenNumber: screen, processID: 1, forcesNewWindow: forcesNewWindow)
    }

    func testOpensNewWindowWhenAppOnlyHasWindowsOnOtherWorkspaces() {
        let state = AeroSpaceState(
            workspaces: [workspace("A"), workspace("B", visible: true, focused: true)],
            windows: [window(1, on: "A"), window(2, on: "B", pid: 2)]
        )
        XCTAssertEqual(action(state), .openNewWindow(workspace: "B"))
    }

    func testFocusesWindowOnCurrentWorkspace() {
        let state = AeroSpaceState(
            workspaces: [workspace("A"), workspace("B", visible: true, focused: true)],
            windows: [window(1, on: "A"), window(2, on: "B")],
            focusedWindowID: 9
        )
        XCTAssertEqual(action(state), .focusWindow(2))
    }

    func testRepeatedClicksStepThroughWindowsOnWorkspace() {
        var state = AeroSpaceState(
            workspaces: [workspace("B", visible: true, focused: true)],
            windows: [window(1, on: "B"), window(2, on: "B"), window(3, on: "B")],
            focusedWindowID: 1
        )
        XCTAssertEqual(action(state), .focusWindow(2))
        state.focusedWindowID = 3
        XCTAssertEqual(action(state), .focusWindow(1), "wraps around")
    }

    func testForcedNewWindowIgnoresExistingWindow() {
        let state = AeroSpaceState(
            workspaces: [workspace("B", visible: true, focused: true)],
            windows: [window(1, on: "B")]
        )
        XCTAssertEqual(action(state, forcesNewWindow: true), .openNewWindow(workspace: "B"))
    }

    func testTargetsWorkspaceShownOnClickedScreenNotFocusedOne() {
        let state = AeroSpaceState(
            workspaces: [
                workspace("A", screen: 1, visible: true, focused: true),
                workspace("B", screen: 2, visible: true)
            ],
            windows: [window(1, on: "A")]
        )
        XCTAssertEqual(action(state, screen: 2), .openNewWindow(workspace: "B"))
        XCTAssertEqual(action(state, screen: 1), .focusWindow(1))
    }

    func testFallsBackToFocusedWorkspaceForUnknownScreen() {
        let state = AeroSpaceState(
            workspaces: [workspace("A", visible: true, focused: true)],
            windows: []
        )
        XCTAssertEqual(action(state, screen: nil), .openNewWindow(workspace: "A"))
        XCTAssertEqual(action(.empty), .openNewWindow(workspace: nil))
    }
}
