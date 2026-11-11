import XCTest

final class PinnedAppMatcherTests: XCTestCase {
    private let pathA = URL(fileURLWithPath: "/Applications/A.app")
    private let pathB = URL(fileURLWithPath: "/Applications/B.app")

    func testSameIdentifierDifferentLocationIsSameApp() {
        XCTAssertTrue(PinnedAppMatcher.isSameApp(
            PinnedApp(bundleIdentifier: "x", bundleURL: pathA),
            PinnedApp(bundleIdentifier: "x", bundleURL: pathB)
        ))
    }

    func testDifferentIdentifiersSameLocationAreDifferentApps() {
        XCTAssertFalse(PinnedAppMatcher.isSameApp(
            PinnedApp(bundleIdentifier: "x", bundleURL: pathA),
            PinnedApp(bundleIdentifier: "y", bundleURL: pathA)
        ))
    }

    func testMissingIdentifierFallsBackToLocation() {
        let withID = PinnedApp(bundleIdentifier: "x", bundleURL: pathA)
        XCTAssertTrue(PinnedAppMatcher.isSameApp(withID, PinnedApp(bundleIdentifier: nil, bundleURL: pathA)))
        XCTAssertFalse(PinnedAppMatcher.isSameApp(withID, PinnedApp(bundleIdentifier: nil, bundleURL: pathB)))
    }

    func testLocationComparisonIsStandardized() {
        let messy = URL(fileURLWithPath: "/Applications/./A.app")
        XCTAssertTrue(PinnedAppMatcher.isSameApp(
            PinnedApp(bundleIdentifier: nil, bundleURL: pathA),
            PinnedApp(bundleIdentifier: nil, bundleURL: messy)
        ))
    }

    func testIsRunningByIdentifier() {
        let pin = PinnedApp(bundleIdentifier: "x", bundleURL: pathA)
        XCTAssertTrue(PinnedAppMatcher.isRunning(pin, resolvedURL: pathA, among: [
            RunningAppDescriptor(bundleIdentifier: "x", bundleURL: pathB)
        ]))
        XCTAssertFalse(PinnedAppMatcher.isRunning(pin, resolvedURL: pathA, among: [
            RunningAppDescriptor(bundleIdentifier: "y", bundleURL: pathA)
        ]))
    }

    func testIsRunningWithoutIdentifierUsesSavedOrResolvedLocation() {
        let pin = PinnedApp(bundleIdentifier: nil, bundleURL: pathA)
        XCTAssertTrue(PinnedAppMatcher.isRunning(pin, resolvedURL: nil, among: [
            RunningAppDescriptor(bundleIdentifier: nil, bundleURL: pathA)
        ]))
        XCTAssertTrue(PinnedAppMatcher.isRunning(pin, resolvedURL: pathB, among: [
            RunningAppDescriptor(bundleIdentifier: nil, bundleURL: pathB)
        ]))
        XCTAssertFalse(PinnedAppMatcher.isRunning(pin, resolvedURL: nil, among: []))
    }

    func testRunningMatchReturnsTheProcess() {
        let pin = PinnedApp(bundleIdentifier: "x", bundleURL: pathA)
        let match = PinnedAppMatcher.runningMatch(pin, resolvedURL: pathA, among: [
            RunningAppDescriptor(bundleIdentifier: "y", bundleURL: pathA, processID: 7),
            RunningAppDescriptor(bundleIdentifier: "x", bundleURL: pathB, processID: 42)
        ])
        XCTAssertEqual(match?.processID, 42)
    }
}
