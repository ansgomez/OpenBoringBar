import Foundation

final class FakePinnedAppStorage: PinnedAppStoring {
    var savedSnapshot: PinnedAppsSnapshot?
    private(set) var saveCount = 0

    init(snapshot: PinnedAppsSnapshot? = nil) {
        self.savedSnapshot = snapshot
    }

    func load() -> PinnedAppsSnapshot? {
        savedSnapshot
    }

    func save(_ snapshot: PinnedAppsSnapshot) {
        savedSnapshot = snapshot
        saveCount += 1
    }
}

final class FakeApplicationLocator: ApplicationLocating {
    /// Bundle identifier stored at each existing path (`nil` value = exists, no identifier).
    var bundles: [URL: String?] = [:]
    /// What Launch Services returns for an identifier.
    var launchServices: [String: URL] = [:]

    func fileExists(at url: URL) -> Bool {
        bundles.keys.contains(url)
    }

    func bundleIdentifier(at url: URL) -> String? {
        bundles[url] ?? nil
    }

    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        launchServices[bundleIdentifier]
    }
}

enum PinnedAppFixtures {
    static let safariURL = URL(fileURLWithPath: "/Applications/Safari.app")
    static let notesURL = URL(fileURLWithPath: "/System/Applications/Notes.app")
    static let safari = PinnedApp(bundleIdentifier: "com.apple.Safari", bundleURL: safariURL)
    static let notes = PinnedApp(bundleIdentifier: "com.apple.Notes", bundleURL: notesURL)
    static let mainUUID = "MAIN-UUID"
    static let otherUUID = "OTHER-UUID"
}
