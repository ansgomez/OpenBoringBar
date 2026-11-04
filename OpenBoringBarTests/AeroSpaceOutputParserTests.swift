import CoreGraphics
import XCTest

final class AeroSpaceOutputParserTests: XCTestCase {
    func testParsesWindows() {
        let output = """
        35071|2|59529|org.alacritty|Alacritty|h_tiles|✳ Project Notes
        41589|A|1234|company.thebrowser.Browser|Arc|floating|Inbox | Mail
        """
        let windows = AeroSpaceOutputParser.windows(from: output)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0], AeroSpaceWindow(
            id: 35071, workspace: "2", processID: 59529, bundleIdentifier: "org.alacritty",
            appName: "Alacritty", layout: "h_tiles", title: "✳ Project Notes"
        ))
        XCTAssertFalse(windows[0].isFloating)
        XCTAssertTrue(windows[1].isFloating)
        XCTAssertEqual(windows[1].title, "Inbox | Mail", "title keeps the separator")
    }

    func testWindowsSkipMalformedLines() {
        let output = "garbage\n\nabc|W|1|x|y|h_tiles|z\n42||1|x|y|h_tiles|z\n7|B|||App|v_tiles|\n"
        let windows = AeroSpaceOutputParser.windows(from: output)
        XCTAssertEqual(windows.map(\.id), [7])
        XCTAssertNil(windows[0].bundleIdentifier)
        XCTAssertNil(windows[0].processID)
        XCTAssertEqual(windows[0].title, "")
    }

    func testParsesWorkspaces() {
        let output = "0|1|false|false\nW|1|true|true\nS|2|true|false\nX||false|false\n"
        XCTAssertEqual(AeroSpaceOutputParser.workspaces(from: output), [
            AeroSpaceWorkspace(name: "0", screenNumber: 1, isVisible: false, isFocused: false),
            AeroSpaceWorkspace(name: "W", screenNumber: 1, isVisible: true, isFocused: true),
            AeroSpaceWorkspace(name: "S", screenNumber: 2, isVisible: true, isFocused: false),
            AeroSpaceWorkspace(name: "X", screenNumber: nil, isVisible: false, isFocused: false)
        ])
    }

    func testFocusedWindowID() {
        XCTAssertEqual(AeroSpaceOutputParser.focusedWindowID(from: "34749\n"), 34749)
        XCTAssertNil(AeroSpaceOutputParser.focusedWindowID(from: ""))
    }

    func testStateDerivedLookups() {
        let state = AeroSpaceState(
            workspaces: [
                AeroSpaceWorkspace(name: "A", screenNumber: 1, isVisible: false, isFocused: false),
                AeroSpaceWorkspace(name: "W", screenNumber: 1, isVisible: true, isFocused: true)
            ],
            windows: [AeroSpaceWindow(
                id: 5, workspace: "A", processID: 1, bundleIdentifier: nil,
                appName: "X", layout: "h_tiles", title: ""
            )]
        )
        XCTAssertEqual(state.focusedWorkspace, "W")
        XCTAssertEqual(state.workspaceByWindowID, [5: "A"])
    }
}
