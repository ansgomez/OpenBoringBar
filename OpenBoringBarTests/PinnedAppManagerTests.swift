import XCTest

final class PinnedAppManagerTests: XCTestCase {
    private typealias F = PinnedAppFixtures

    private var storage: FakePinnedAppStorage!
    private var locator: FakeApplicationLocator!

    override func setUp() {
        super.setUp()
        storage = FakePinnedAppStorage()
        locator = FakeApplicationLocator()
        locator.bundles = [F.safariURL: F.safari.bundleIdentifier, F.notesURL: F.notes.bundleIdentifier]
    }

    private func makeManager() -> PinnedAppManager {
        PinnedAppManager(storage: storage, locator: locator)
    }

    // MARK: Loading and saving

    func testEmptyStorageStartsWithAllDisplaysAndNoPins() {
        let manager = makeManager()
        XCTAssertEqual(manager.mode, .allDisplays)
        XCTAssertEqual(manager.pins(forDisplayUUID: F.mainUUID, isMainDisplay: true), [])
    }

    func testPinsSurviveReloadInOrder() {
        let manager = makeManager()
        manager.pin(F.safari, displayUUID: F.mainUUID, isMainDisplay: true)
        manager.pin(F.notes, displayUUID: F.mainUUID, isMainDisplay: true)

        let reloaded = makeManager()
        XCTAssertEqual(reloaded.pins(forDisplayUUID: nil, isMainDisplay: true), [F.safari, F.notes])
    }

    func testSetModeIsSaved() {
        makeManager().setMode(.perDisplay)
        XCTAssertEqual(makeManager().mode, .perDisplay)
    }

    func testPinningDuplicateIsNoOp() {
        let manager = makeManager()
        manager.pin(F.safari, displayUUID: nil, isMainDisplay: true)
        let moved = PinnedApp(bundleIdentifier: F.safari.bundleIdentifier, bundleURL: URL(fileURLWithPath: "/tmp/Safari.app"))
        manager.pin(moved, displayUUID: nil, isMainDisplay: true)
        XCTAssertEqual(manager.pins(forDisplayUUID: nil, isMainDisplay: true), [F.safari])
    }

    func testIsPinned() {
        let manager = makeManager()
        manager.pin(F.safari, displayUUID: nil, isMainDisplay: true)
        XCTAssertTrue(manager.isPinned(F.safari, displayUUID: nil, isMainDisplay: true))
        XCTAssertFalse(manager.isPinned(F.notes, displayUUID: nil, isMainDisplay: true))
    }

    // MARK: Reordering

    private static let mail = PinnedApp(
        bundleIdentifier: "com.apple.mail",
        bundleURL: URL(fileURLWithPath: "/System/Applications/Mail.app")
    )

    private func makeManagerWithThreePins() -> PinnedAppManager {
        let manager = makeManager()
        for app in [F.safari, F.notes, Self.mail] {
            manager.pin(app, displayUUID: nil, isMainDisplay: true)
        }
        return manager
    }

    func testMoveBeforeAnchor() {
        let manager = makeManagerWithThreePins()
        manager.move(Self.mail, before: F.safari, displayUUID: nil, isMainDisplay: true)
        XCTAssertEqual(manager.pins(forDisplayUUID: nil, isMainDisplay: true), [Self.mail, F.safari, F.notes])
    }

    func testMoveToEndWithNilAnchor() {
        let manager = makeManagerWithThreePins()
        manager.move(F.safari, before: nil, displayUUID: nil, isMainDisplay: true)
        XCTAssertEqual(manager.pins(forDisplayUUID: nil, isMainDisplay: true), [F.notes, Self.mail, F.safari])
    }

    func testMoveRightSkippingOneUsesAnchorAfterNeighbor() {
        let manager = makeManagerWithThreePins()
        manager.move(F.safari, before: Self.mail, displayUUID: nil, isMainDisplay: true)
        XCTAssertEqual(manager.pins(forDisplayUUID: nil, isMainDisplay: true), [F.notes, F.safari, Self.mail])
    }

    func testMoveBeforeItselfIsNoOp() {
        let manager = makeManagerWithThreePins()
        manager.move(F.notes, before: F.notes, displayUUID: nil, isMainDisplay: true)
        XCTAssertEqual(manager.pins(forDisplayUUID: nil, isMainDisplay: true), [F.safari, F.notes, Self.mail])
    }

    func testMoveIsSaved() {
        makeManagerWithThreePins().move(Self.mail, before: F.safari, displayUUID: nil, isMainDisplay: true)
        XCTAssertEqual(makeManager().pins(forDisplayUUID: nil, isMainDisplay: true), [Self.mail, F.safari, F.notes])
    }

    func testPerDisplayMoveChangesOnlyThatDisplay() {
        let manager = makeManagerWithThreePins()
        manager.setMode(.perDisplay)
        manager.move(Self.mail, before: F.safari, displayUUID: F.otherUUID, isMainDisplay: false)
        XCTAssertEqual(manager.pins(forDisplayUUID: F.otherUUID, isMainDisplay: false), [Self.mail, F.safari, F.notes])
        XCTAssertEqual(manager.pins(forDisplayUUID: F.mainUUID, isMainDisplay: true), [F.safari, F.notes, Self.mail])
    }

    func testMoveOnNonMainDisplayInMainDisplayOnlyIsIgnored() {
        let manager = makeManagerWithThreePins()
        manager.setMode(.mainDisplayOnly)
        manager.move(Self.mail, before: F.safari, displayUUID: F.otherUUID, isMainDisplay: false)
        XCTAssertEqual(manager.pins(forDisplayUUID: F.mainUUID, isMainDisplay: true), [F.safari, F.notes, Self.mail])
    }

    // MARK: Resolution

    func testValidSavedLocationIsUsed() {
        XCTAssertEqual(makeManager().resolvedURL(for: F.safari), F.safariURL)
    }

    func testMovedAppIsFoundByIdentifierAndNewLocationSavedEverywhere() {
        let movedURL = URL(fileURLWithPath: "/Users/me/Applications/Safari.app")
        locator.bundles = [movedURL: F.safari.bundleIdentifier]
        locator.launchServices = [F.safari.bundleIdentifier!: movedURL]
        storage.savedSnapshot = PinnedAppsSnapshot(
            version: PinnedAppsSnapshot.currentVersion,
            mode: .allDisplays,
            sharedPins: [F.safari],
            perDisplayPins: [F.otherUUID: [F.safari]]
        )

        let manager = makeManager()
        XCTAssertEqual(manager.resolvedURL(for: F.safari), movedURL)
        XCTAssertEqual(storage.savedSnapshot?.sharedPins.first?.bundleURL, movedURL)
        XCTAssertEqual(storage.savedSnapshot?.perDisplayPins[F.otherUUID]?.first?.bundleURL, movedURL)
    }

    func testSavedLocationWithDifferentIdentifierFallsBackToLookup() {
        let realURL = URL(fileURLWithPath: "/Applications/Real Safari.app")
        locator.bundles = [F.safariURL: "com.example.Other", realURL: F.safari.bundleIdentifier]
        locator.launchServices = [F.safari.bundleIdentifier!: realURL]
        XCTAssertEqual(makeManager().resolvedURL(for: F.safari), realURL)
    }

    func testUnresolvablePinIsKept() {
        storage.savedSnapshot = PinnedAppsSnapshot(
            version: PinnedAppsSnapshot.currentVersion,
            mode: .allDisplays,
            sharedPins: [F.safari],
            perDisplayPins: [:]
        )
        locator.bundles = [:]

        let manager = makeManager()
        XCTAssertNil(manager.resolvedURL(for: F.safari))
        XCTAssertEqual(manager.pins(forDisplayUUID: nil, isMainDisplay: true), [F.safari])
        XCTAssertEqual(storage.savedSnapshot?.sharedPins, [F.safari])
    }

    func testPinWithoutIdentifierAndMissingLocationIsUnresolved() {
        locator.bundles = [:]
        let pin = PinnedApp(bundleIdentifier: nil, bundleURL: F.safariURL)
        XCTAssertNil(makeManager().resolvedURL(for: pin))
    }

    // MARK: Display modes

    func testMainDisplayOnlyShowsAndEditsOnlyOnMainDisplay() {
        let manager = makeManager()
        manager.pin(F.safari, displayUUID: F.mainUUID, isMainDisplay: true)
        manager.setMode(.mainDisplayOnly)

        XCTAssertEqual(manager.pins(forDisplayUUID: F.mainUUID, isMainDisplay: true), [F.safari])
        XCTAssertEqual(manager.pins(forDisplayUUID: F.otherUUID, isMainDisplay: false), [])
        XCTAssertFalse(manager.canEditPins(isMainDisplay: false))

        manager.pin(F.notes, displayUUID: F.otherUUID, isMainDisplay: false)
        manager.unpin(F.safari, displayUUID: F.otherUUID, isMainDisplay: false)
        XCTAssertEqual(manager.pins(forDisplayUUID: F.mainUUID, isMainDisplay: true), [F.safari])
    }

    func testPerDisplayFirstEditCopiesSharedListAndLeavesOthersAlone() {
        let manager = makeManager()
        manager.pin(F.safari, displayUUID: nil, isMainDisplay: true)
        manager.pin(F.notes, displayUUID: nil, isMainDisplay: true)
        manager.setMode(.perDisplay)

        XCTAssertEqual(manager.pins(forDisplayUUID: F.otherUUID, isMainDisplay: false), [F.safari, F.notes])

        manager.unpin(F.safari, displayUUID: F.otherUUID, isMainDisplay: false)

        XCTAssertEqual(manager.pins(forDisplayUUID: F.otherUUID, isMainDisplay: false), [F.notes])
        XCTAssertEqual(manager.pins(forDisplayUUID: F.mainUUID, isMainDisplay: true), [F.safari, F.notes])

        manager.setMode(.allDisplays)
        XCTAssertEqual(manager.pins(forDisplayUUID: F.otherUUID, isMainDisplay: false), [F.safari, F.notes])

        manager.setMode(.perDisplay)
        XCTAssertEqual(manager.pins(forDisplayUUID: F.otherUUID, isMainDisplay: false), [F.notes])
    }

    func testPerDisplayWithoutUUIDUsesSharedList() {
        let manager = makeManager()
        manager.setMode(.perDisplay)
        manager.pin(F.safari, displayUUID: nil, isMainDisplay: true)

        XCTAssertEqual(storage.savedSnapshot?.sharedPins, [F.safari])
        XCTAssertEqual(storage.savedSnapshot?.perDisplayPins, [:])
        XCTAssertEqual(manager.pins(forDisplayUUID: nil, isMainDisplay: true), [F.safari])
    }
}
