import XCTest

final class FolderEntrySorterTests: XCTestCase {
    private func entry(_ name: String, dir: Bool = false, added: TimeInterval? = nil, modified: TimeInterval? = nil) -> FolderEntry {
        FolderEntry(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: dir,
            dateAdded: added.map(Date.init(timeIntervalSince1970:)),
            dateModified: modified.map(Date.init(timeIntervalSince1970:))
        )
    }

    func testNameOrderIsFinderLikeWithFoldersFirst() {
        let entries = [entry("b10.txt"), entry("Zeta", dir: true), entry("b2.txt"), entry("alpha", dir: true)]
        let sorted = FolderEntrySorter.sorted(entries, by: .name, keepingFoldersOnTop: true)
        XCTAssertEqual(sorted.map(\.name), ["alpha", "Zeta", "b2.txt", "b10.txt"])
    }

    func testNameOrderMixedWhenFoldersNotOnTop() {
        let entries = [entry("c"), entry("b", dir: true), entry("a")]
        XCTAssertEqual(FolderEntrySorter.sorted(entries, by: .name, keepingFoldersOnTop: false).map(\.name), ["a", "b", "c"])
    }

    func testDateAddedNewestFirstFallsBackToModifiedThenName() {
        let entries = [
            entry("old", added: 100),
            entry("new", added: 300),
            entry("noAddedDate", modified: 200),
            entry("b-undated"), entry("a-undated")
        ]
        let sorted = FolderEntrySorter.sorted(entries, by: .dateAdded, keepingFoldersOnTop: false)
        XCTAssertEqual(sorted.map(\.name), ["new", "noAddedDate", "old", "a-undated", "b-undated"])
    }

    func testDateModifiedNewestFirst() {
        let entries = [entry("a", modified: 1), entry("b", modified: 5)]
        XCTAssertEqual(FolderEntrySorter.sorted(entries, by: .dateModified, keepingFoldersOnTop: false).map(\.name), ["b", "a"])
    }
}

final class FolderPeekImporterTests: XCTestCase {
    private func json(bookmark: String, sort: String = "name", onTop: Bool = true, visible: Bool = true) -> String {
        "{\"urlBookmark\":\"\(bookmark)\",\"sortOrder\":\"\(sort)\",\"keepFoldersOnTop\":\(onTop),\"isVisible\":\(visible)}"
    }

    func testMapsEntriesAndSkipsUnresolvableHiddenAndInvalid() {
        let good = Data("one".utf8).base64EncodedString()
        let other = Data("two".utf8).base64EncodedString()
        let broken = Data("broken".utf8).base64EncodedString()
        let entries = [
            json(bookmark: good),
            json(bookmark: other, sort: "dateAdded", onTop: false),
            json(bookmark: broken),
            json(bookmark: good, visible: false),
            "not json"
        ]
        let folders = FolderPeekImporter.folders(fromEntries: entries) { data in
            switch String(decoding: data, as: UTF8.self) {
            case "one": return "/Users/me/git"
            case "two": return "/Users/me/Downloads"
            default: return nil
            }
        }
        XCTAssertEqual(folders, [
            PeekFolder(path: "/Users/me/git", sortOrder: .name, keepsFoldersOnTop: true),
            PeekFolder(path: "/Users/me/Downloads", sortOrder: .dateAdded, keepsFoldersOnTop: false)
        ])
    }

    func testMissingPreferencesFileImportsNothing() {
        XCTAssertEqual(FolderPeekImporter.importFolders(from: URL(fileURLWithPath: "/nonexistent.plist")), [])
    }
}

final class FolderPeekManagerTests: XCTestCase {
    private final class MemoryStorage: PeekFolderStoring {
        var saved: [PeekFolder]?
        init(_ saved: [PeekFolder]? = nil) { self.saved = saved }
        func load() -> [PeekFolder]? { saved }
        func save(_ folders: [PeekFolder]) { saved = folders }
    }

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "FolderPeekManagerTests")
        defaults.removePersistentDomain(forName: "FolderPeekManagerTests")
    }

    func testFirstLaunchUsesAndSavesInitialFolders() {
        let storage = MemoryStorage()
        let initial = [PeekFolder(path: "/a", sortOrder: .name, keepsFoldersOnTop: true)]
        let manager = FolderPeekManager(storage: storage, defaults: defaults, initialFolders: { initial })
        XCTAssertEqual(manager.folders, initial)
        XCTAssertEqual(storage.saved, initial)
    }

    func testSavedListWinsOverInitialFolders() {
        let saved = [PeekFolder(path: "/saved", sortOrder: .name, keepsFoldersOnTop: true)]
        let manager = FolderPeekManager(storage: MemoryStorage(saved), defaults: defaults, initialFolders: {
            XCTFail("must not import when a list is saved")
            return []
        })
        XCTAssertEqual(manager.folders, saved)
    }

    func testAddRemoveAndSortOrderPersist() {
        let storage = MemoryStorage([])
        let manager = FolderPeekManager(storage: storage, defaults: defaults)
        manager.add(URL(fileURLWithPath: "/x/"))
        manager.add(URL(fileURLWithPath: "/x"))
        XCTAssertEqual(manager.folders.map(\.path), ["/x"], "no duplicates")

        manager.setSortOrder(.dateAdded, for: manager.folders[0])
        XCTAssertEqual(storage.saved?.first?.sortOrder, .dateAdded)

        manager.remove(manager.folders[0])
        XCTAssertEqual(storage.saved, [])
    }

    func testShowFoldersSettingPersists() {
        let manager = FolderPeekManager(storage: MemoryStorage([]), defaults: defaults)
        XCTAssertTrue(manager.isEnabled)
        manager.setEnabled(false)
        XCTAssertFalse(FolderPeekManager(storage: MemoryStorage([]), defaults: defaults).isEnabled)
    }

    func testStorageRoundTrip() {
        let storage = PeekFolderStorageProvider(defaults: defaults)
        XCTAssertNil(storage.load())
        let folders = [PeekFolder(path: "/p", sortOrder: .dateModified, keepsFoldersOnTop: false)]
        storage.save(folders)
        XCTAssertEqual(storage.load(), folders)
    }
}

final class PeekFolderCustomizationTests: XCTestCase {
    private final class MemoryStorage: PeekFolderStoring {
        var saved: [PeekFolder]?
        init(_ saved: [PeekFolder]?) { self.saved = saved }
        func load() -> [PeekFolder]? { saved }
        func save(_ folders: [PeekFolder]) { saved = folders }
    }

    func testDecodesFoldersSavedBeforeIconFieldsExisted() throws {
        let json = #"[{"path":"/Users/me/git","sortOrder":"name","keepsFoldersOnTop":true}]"#
        // (also covers badgeColor, added later)
        let folders = try JSONDecoder().decode([PeekFolder].self, from: Data(json.utf8))
        XCTAssertEqual(folders.first?.path, "/Users/me/git")
        XCTAssertNil(folders.first?.customIconPath)
        XCTAssertNil(folders.first?.badgeImagePath)
        XCTAssertNil(folders.first?.badgeSymbol)
    }

    func testFolderMovesBetweenBarAndStartMenu() {
        let defaults = UserDefaults(suiteName: "PeekFolderStartMenuTests")!
        defaults.removePersistentDomain(forName: "PeekFolderStartMenuTests")
        let storage = MemoryStorage([
            PeekFolder(path: "/a", sortOrder: .name, keepsFoldersOnTop: true),
            PeekFolder(path: "/b", sortOrder: .name, keepsFoldersOnTop: true)
        ])
        let manager = FolderPeekManager(storage: storage, defaults: defaults)
        XCTAssertEqual(manager.barFolders.map(\.path), ["/a", "/b"])

        manager.setInStartMenu(true, for: manager.folders[0])
        XCTAssertEqual(manager.barFolders.map(\.path), ["/b"])
        XCTAssertEqual(manager.startMenuFolders.map(\.path), ["/a"])
        XCTAssertEqual(storage.saved?.first?.isInStartMenu, true)

        manager.setInStartMenu(false, for: manager.folders[0])
        XCTAssertTrue(manager.startMenuFolders.isEmpty)
    }

    func testBadgeImageAndSymbolReplaceEachOther() {
        let defaults = UserDefaults(suiteName: "PeekFolderCustomizationTests")!
        defaults.removePersistentDomain(forName: "PeekFolderCustomizationTests")
        let storage = MemoryStorage([PeekFolder(path: "/g", sortOrder: .name, keepsFoldersOnTop: true)])
        let manager = FolderPeekManager(storage: storage, defaults: defaults)

        manager.setBadgeSymbol("star.fill", for: manager.folders[0])
        manager.setBadgeImage(path: "/icons/git.png", for: manager.folders[0])
        XCTAssertEqual(storage.saved?.first?.badgeImagePath, "/icons/git.png")
        XCTAssertNil(storage.saved?.first?.badgeSymbol)

        manager.setBadgeSymbol("book.closed.fill", for: manager.folders[0])
        XCTAssertNil(storage.saved?.first?.badgeImagePath)
        XCTAssertEqual(storage.saved?.first?.badgeColor, .orange, "preset default color")

        manager.setBadgeColor(.pink, for: manager.folders[0])
        XCTAssertEqual(storage.saved?.first?.badgeColor, .pink)

        manager.setCustomIcon(path: "/icons/custom.png", for: manager.folders[0])
        manager.removeBadge(for: manager.folders[0])
        XCTAssertEqual(storage.saved?.first?.customIconPath, "/icons/custom.png")
        XCTAssertNil(storage.saved?.first?.badgeSymbol)

        XCTAssertNil(storage.saved?.first?.badgeColor, "No Badge clears the color")

        manager.setCustomIcon(path: nil, for: manager.folders[0])
        XCTAssertNil(storage.saved?.first?.customIconPath)
    }

    func testPresetDefaultColorsAreDistinctForCommonNeighbors() {
        let colors = [FolderBadgePreset.download, .book, .chip, .branch, .code].map(\.defaultColor)
        XCTAssertEqual(Set(colors).count, colors.count)
    }
}
