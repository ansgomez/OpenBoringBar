import XCTest

final class PinnedAppStorageProviderTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "OpenBoringBarTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testNothingSavedLoadsNil() {
        XCTAssertNil(PinnedAppStorageProvider(defaults: defaults).load())
    }

    func testRoundTrip() {
        let snapshot = PinnedAppsSnapshot(
            version: PinnedAppsSnapshot.currentVersion,
            mode: .perDisplay,
            sharedPins: [PinnedAppFixtures.safari],
            perDisplayPins: [PinnedAppFixtures.otherUUID: [PinnedAppFixtures.notes]]
        )
        let storage = PinnedAppStorageProvider(defaults: defaults)
        storage.save(snapshot)
        XCTAssertEqual(storage.load(), snapshot)
    }

    func testUndecodableDataLoadsNil() {
        defaults.set(Data("not json".utf8), forKey: PinnedAppStorageProvider.defaultsKey)
        XCTAssertNil(PinnedAppStorageProvider(defaults: defaults).load())
    }

    func testUnknownVersionLoadsNil() {
        var snapshot = PinnedAppsSnapshot.empty
        snapshot.version = PinnedAppsSnapshot.currentVersion + 1
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: PinnedAppStorageProvider.defaultsKey)
        XCTAssertNil(PinnedAppStorageProvider(defaults: defaults).load())
    }
}
