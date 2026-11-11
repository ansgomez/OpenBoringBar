import XCTest

private final class FakeAppUsageStorage: AppUsageStoring {
    var saved: AppUsageSnapshot?

    init(_ snapshot: AppUsageSnapshot? = nil) {
        saved = snapshot
    }

    func load() -> AppUsageSnapshot? { saved }
    func save(_ snapshot: AppUsageSnapshot) { saved = snapshot }
}

final class AppUsageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 3600

    private func app(_ name: String, id: String? = nil) -> LaunchableApplicationItem {
        LaunchableApplicationItem(
            bundleURL: URL(fileURLWithPath: "/Applications/\(name).app"),
            name: name,
            bundleIdentifier: id ?? "com.test.\(name.lowercased())"
        )
    }

    func testScoreHalvesAfterHalfLife() {
        let record = AppUsageRecord(score: 8, lastUsed: now.addingTimeInterval(-AppUsageCalculator.halfLife))
        XCTAssertEqual(AppUsageCalculator.score(of: record, at: now), 4, accuracy: 0.001)
    }

    func testRecordingUseAddsOneToDecayedScore() {
        let old = AppUsageRecord(score: 8, lastUsed: now.addingTimeInterval(-AppUsageCalculator.halfLife))
        let updated = AppUsageCalculator.recordingUse(on: old, at: now)
        XCTAssertEqual(updated.score, 5, accuracy: 0.001)
        XCTAssertEqual(updated.lastUsed, now)
        XCTAssertEqual(AppUsageCalculator.recordingUse(on: nil, at: now).score, 1)
    }

    func testSeedSkipsStaleAndUnusedApps() {
        let stale = AppUsageSeed(bundleIdentifier: "a", useCount: 12_000, lastUsed: now.addingTimeInterval(-60 * day))
        let unused = AppUsageSeed(bundleIdentifier: "b", useCount: 0, lastUsed: now)
        let recent = AppUsageSeed(bundleIdentifier: "c", useCount: 1023, lastUsed: now.addingTimeInterval(-day))
        XCTAssertNil(AppUsageCalculator.seedRecord(from: stale, now: now))
        XCTAssertNil(AppUsageCalculator.seedRecord(from: unused, now: now))
        XCTAssertEqual(AppUsageCalculator.seedRecord(from: recent, now: now)?.score ?? 0, 10, accuracy: 0.001)
    }

    func testFrequentApplicationsRanksExcludesPinsAndLimits() {
        let installed = [app("Alpha"), app("Beta"), app("Gamma"), app("Delta"), app("NoID", id: nil)]
        let records: [String: AppUsageRecord] = [
            "com.test.alpha": AppUsageRecord(score: 2, lastUsed: now),
            "com.test.beta": AppUsageRecord(score: 9, lastUsed: now),
            "com.test.gamma": AppUsageRecord(score: 5, lastUsed: now),
            // High score long ago: decayed below Alpha.
            "com.test.delta": AppUsageRecord(score: 100, lastUsed: now.addingTimeInterval(-365 * day)),
            "com.test.notinstalled": AppUsageRecord(score: 50, lastUsed: now)
        ]
        let ranked = AppUsageCalculator.frequentApplications(
            among: installed, records: records,
            excludedBundleIdentifiers: ["com.test.gamma"], limit: 2, now: now
        )
        XCTAssertEqual(ranked.map(\.name), ["Beta", "Alpha"])
    }

    func testFrequentApplicationsAlwaysIncludesPinsUnlessRemoved() {
        let installed = [app("Alpha"), app("Beta"), app("Gamma"), app("Delta")]
        let records: [String: AppUsageRecord] = [
            "com.test.alpha": AppUsageRecord(score: 2, lastUsed: now),
            "com.test.beta": AppUsageRecord(score: 9, lastUsed: now),
            "com.test.gamma": AppUsageRecord(score: 5, lastUsed: now)
        ]
        // Alpha misses the cut of 1 and Delta was never used; both are pinned.
        let pins: Set<String> = ["com.test.alpha", "com.test.delta"]
        let ranked = AppUsageCalculator.frequentApplications(
            among: installed, records: records, excludedBundleIdentifiers: [],
            alwaysIncludedBundleIdentifiers: pins, limit: 1, now: now
        )
        XCTAssertEqual(ranked.map(\.name), ["Beta", "Alpha", "Delta"])

        let withoutAlpha = AppUsageCalculator.frequentApplications(
            among: installed, records: records, excludedBundleIdentifiers: ["com.test.alpha"],
            alwaysIncludedBundleIdentifiers: pins, limit: 1, now: now
        )
        XCTAssertEqual(withoutAlpha.map(\.name), ["Beta", "Delta"], "removed apps stay out even when pinned")
    }

    func testManagerRemembersRemovedApps() {
        let storage = FakeAppUsageStorage()
        let manager = AppUsageManager(storage: storage, now: { self.now })
        manager.recordUse(ofBundleIdentifier: "com.test.alpha")
        manager.recordUse(ofBundleIdentifier: "com.test.beta")
        manager.hide(bundleIdentifier: "com.test.alpha")

        let reloaded = AppUsageManager(storage: storage, now: { self.now })
        XCTAssertEqual(reloaded.hiddenCount, 1)
        let apps = [app("Alpha"), app("Beta")]
        XCTAssertEqual(
            reloaded.frequentApplications(among: apps, alwaysIncludedBundleIdentifiers: [], limit: 5).map(\.name),
            ["Beta"]
        )
        reloaded.unhideAll()
        XCTAssertEqual(
            reloaded.frequentApplications(among: apps, alwaysIncludedBundleIdentifiers: [], limit: 5).count, 2
        )
    }

    func testManagerCountsSavesAndSeedsOnlyUncountedApps() {
        let storage = FakeAppUsageStorage()
        let manager = AppUsageManager(storage: storage, now: { self.now })
        XCTAssertTrue(manager.needsSeed)

        manager.recordUse(ofBundleIdentifier: "com.test.alpha")
        XCTAssertFalse(manager.needsSeed)
        manager.seed([
            AppUsageSeed(bundleIdentifier: "com.test.alpha", useCount: 9999, lastUsed: now),
            AppUsageSeed(bundleIdentifier: "com.test.beta", useCount: 7, lastUsed: now)
        ])
        XCTAssertEqual(storage.saved?.records["com.test.alpha"]?.score, 1, "counted uses are not overwritten")
        XCTAssertEqual(storage.saved?.records["com.test.beta"]?.score ?? 0, 3, accuracy: 0.001)

        let reloaded = AppUsageManager(storage: storage, now: { self.now })
        XCTAssertFalse(reloaded.needsSeed)
        XCTAssertEqual(
            reloaded.frequentApplications(
                among: [app("Alpha"), app("Beta")], alwaysIncludedBundleIdentifiers: [], limit: 5
            ).map(\.name),
            ["Beta", "Alpha"]
        )
    }
}
