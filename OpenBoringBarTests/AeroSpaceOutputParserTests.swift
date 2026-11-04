import CoreGraphics
import XCTest

final class AeroSpaceOutputParserTests: XCTestCase {
    func testParsesWindowIDsAndWorkspaces() {
        let output = "35071|2\n38516|W\n41833|S\n"
        XCTAssertEqual(
            AeroSpaceOutputParser.workspaceByWindowID(from: output),
            [35071: "2", 38516: "W", 41833: "S"]
        )
    }

    func testSkipsMalformedAndEmptyLines() {
        let output = "garbage\n\n123|\nabc|W\n42| B \n"
        XCTAssertEqual(AeroSpaceOutputParser.workspaceByWindowID(from: output), [42: "B"])
    }

    func testWorkspaceNameMayContainSeparator() {
        XCTAssertEqual(AeroSpaceOutputParser.workspaceByWindowID(from: "7|a|b"), [7: "a|b"])
    }
}
