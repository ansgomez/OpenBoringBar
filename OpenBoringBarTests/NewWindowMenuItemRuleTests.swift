import XCTest

final class NewWindowMenuItemRuleTests: XCTestCase {
    private func item(
        _ title: String,
        key: String? = nil,
        modifiers: Int? = nil,
        enabled: Bool = true,
        submenu: Bool = false
    ) -> AppMenuItemInfo {
        AppMenuItemInfo(
            title: title,
            commandCharacter: key,
            commandModifiers: key == nil ? nil : (modifiers ?? 0),
            isEnabled: enabled,
            hasSubmenu: submenu
        )
    }

    private func bestTitle(_ items: [AppMenuItemInfo]) -> String? {
        NewWindowMenuItemRule.bestIndex(in: items).map { items[$0].title }
    }

    func testPlainClickDoesNotPressCommandNThatCreatesData() {
        let notes = [item("New Note", key: "N"), item("New Folder", key: "N", modifiers: 1)]
        XCTAssertNil(NewWindowMenuItemRule.bestIndex(in: notes, isExplicitRequest: false))
        XCTAssertEqual(NewWindowMenuItemRule.bestIndex(in: notes, isExplicitRequest: true), 0)

        let textMate = [item("New", key: "N"), item("Open…", key: "O")]
        XCTAssertEqual(NewWindowMenuItemRule.bestIndex(in: textMate, isExplicitRequest: false), 0)

        let finder = [item("New Finder Window", key: "N")]
        XCTAssertEqual(NewWindowMenuItemRule.bestIndex(in: finder, isExplicitRequest: false), 0)
    }

    func testPrefersExactNewWindowOverCommandN() {
        // VS Code: Command-N is a new file, New Window is Shift-Command-N.
        let items = [
            item("New Text File", key: "N"),
            item("New Window", key: "N", modifiers: 1)
        ]
        XCTAssertEqual(bestTitle(items), "New Window")
    }

    func testSkipsPrivateAndTabItems() {
        let items = [
            item("New Tab", key: "T"),
            item("New Incognito Window", key: "N", modifiers: 1),
            item("New Private Window", key: "N", modifiers: 1),
            item("New Finder Window", key: "N")
        ]
        XCTAssertEqual(bestTitle(items), "New Finder Window")
    }

    func testNamedWindowItemBeatsCommandN() {
        // Mail: Command-N is a new message.
        let items = [
            item("New Message", key: "N"),
            item("New Viewer Window", key: "N", modifiers: 2)
        ]
        XCTAssertEqual(bestTitle(items), "New Viewer Window")
    }

    func testSubmenuParentIsNotPressedButItsCommandNChildIs() {
        // Terminal: "New Window" is a submenu of profiles.
        let items = [
            item("New Window", submenu: true),
            item("Basic", key: "N"),
            item("Pro")
        ]
        XCTAssertEqual(bestTitle(items), "Basic")
    }

    func testFallsBackToCommandNInAnyLanguage() {
        let items = [
            item("Neues Fenster", key: "N"),
            item("Neuer Tab", key: "T")
        ]
        XCTAssertEqual(bestTitle(items), "Neues Fenster")
    }

    func testIgnoresDisabledItemsAndOtherModifiers() {
        XCTAssertNil(bestTitle([
            item("New Window", enabled: false),
            item("New Folder", key: "N", modifiers: 1),
            item("Open…", key: "O")
        ]))
    }

    func testReadsOnlySubmenusTitledNew() {
        XCTAssertTrue(NewWindowMenuItemRule.shouldReadSubmenu(titled: "New Window"))
        XCTAssertTrue(NewWindowMenuItemRule.shouldReadSubmenu(titled: "New"))
        XCTAssertFalse(NewWindowMenuItemRule.shouldReadSubmenu(titled: "Open Recent"))
        XCTAssertFalse(NewWindowMenuItemRule.shouldReadSubmenu(titled: "Services"))
    }
}
