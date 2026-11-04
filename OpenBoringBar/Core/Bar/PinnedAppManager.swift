import Foundation

/// Owns pin state: which apps are pinned on which bar, the display mode, and
/// finding each pinned app on disk. Every change is saved at once.
///
/// Pins are never deleted automatically. A pin whose app cannot be found is
/// kept and simply not drawn, so a late-mounting drive or an app mid-update
/// does not lose it.
final class PinnedAppManager {
    private let storage: PinnedAppStoring
    private let locator: ApplicationLocating
    private var snapshot: PinnedAppsSnapshot

    init(storage: PinnedAppStoring, locator: ApplicationLocating) {
        self.storage = storage
        self.locator = locator
        self.snapshot = storage.load() ?? .empty
    }

    var mode: PinDisplayMode {
        snapshot.mode
    }

    func setMode(_ mode: PinDisplayMode) {
        guard mode != snapshot.mode else {
            return
        }
        snapshot.mode = mode
        save()
    }

    /// In `mainDisplayOnly`, bars other than the main one show no pins and
    /// offer no pin actions.
    func canEditPins(isMainDisplay: Bool) -> Bool {
        mode != .mainDisplayOnly || isMainDisplay
    }

    /// The saved pins a bar shows, in order, including ones that cannot be
    /// found right now. In `perDisplay`, a display without its own list (or
    /// with no UUID) shows the shared list.
    func pins(forDisplayUUID displayUUID: String?, isMainDisplay: Bool) -> [PinnedApp] {
        switch mode {
        case .allDisplays:
            return snapshot.sharedPins
        case .mainDisplayOnly:
            return isMainDisplay ? snapshot.sharedPins : []
        case .perDisplay:
            guard let displayUUID, let pins = snapshot.perDisplayPins[displayUUID] else {
                return snapshot.sharedPins
            }
            return pins
        }
    }

    func isPinned(_ app: PinnedApp, displayUUID: String?, isMainDisplay: Bool) -> Bool {
        pins(forDisplayUUID: displayUUID, isMainDisplay: isMainDisplay)
            .contains { PinnedAppMatcher.isSameApp($0, app) }
    }

    /// Adds `app` to the end of the list this bar shows. No-op if already there.
    func pin(_ app: PinnedApp, displayUUID: String?, isMainDisplay: Bool) {
        guard canEditPins(isMainDisplay: isMainDisplay) else {
            return
        }
        editList(forDisplayUUID: displayUUID) { pins in
            guard !pins.contains(where: { PinnedAppMatcher.isSameApp($0, app) }) else {
                return
            }
            pins.append(app)
        }
    }

    /// Removes `app` from the list this bar shows only.
    func unpin(_ app: PinnedApp, displayUUID: String?, isMainDisplay: Bool) {
        guard canEditPins(isMainDisplay: isMainDisplay) else {
            return
        }
        editList(forDisplayUUID: displayUUID) { pins in
            pins.removeAll { PinnedAppMatcher.isSameApp($0, app) }
        }
    }

    /// Moves `app` so it sits just before `anchor` in the list this bar
    /// shows, or to the end when `anchor` is `nil`. Callers pick the anchor
    /// from the icons that are drawn, so hidden (unresolved) pins never make
    /// a move look like a no-op.
    func move(
        _ app: PinnedApp,
        before anchor: PinnedApp?,
        displayUUID: String?,
        isMainDisplay: Bool
    ) {
        guard canEditPins(isMainDisplay: isMainDisplay) else {
            return
        }
        if let anchor, PinnedAppMatcher.isSameApp(anchor, app) {
            return
        }
        editList(forDisplayUUID: displayUUID) { pins in
            guard let sourceIndex = pins.firstIndex(where: { PinnedAppMatcher.isSameApp($0, app) }) else {
                return
            }
            let moving = pins.remove(at: sourceIndex)
            let destinationIndex = anchor.flatMap { anchor in
                pins.firstIndex(where: { PinnedAppMatcher.isSameApp($0, anchor) })
            } ?? pins.endIndex
            pins.insert(moving, at: destinationIndex)
        }
    }

    /// Finds the app on disk:
    /// 1. the saved location, if it exists and holds the same identifier
    ///    (or the pin has no identifier);
    /// 2. otherwise, Launch Services' location for the identifier, which is
    ///    then saved in every list that has this pin;
    /// 3. otherwise `nil`. The pin is kept.
    func resolvedURL(for pin: PinnedApp) -> URL? {
        if locator.fileExists(at: pin.bundleURL) {
            guard let identifier = pin.bundleIdentifier else {
                return pin.bundleURL
            }
            if locator.bundleIdentifier(at: pin.bundleURL) == identifier {
                return pin.bundleURL
            }
        }

        guard let identifier = pin.bundleIdentifier,
              let foundURL = locator.applicationURL(forBundleIdentifier: identifier) else {
            return nil
        }

        updateSavedLocation(ofIdentifier: identifier, to: foundURL)
        return foundURL
    }

    private func editList(
        forDisplayUUID displayUUID: String?,
        _ change: (inout [PinnedApp]) -> Void
    ) {
        if mode == .perDisplay, let displayUUID {
            // First edit on a display copies the shared list to it.
            var pins = snapshot.perDisplayPins[displayUUID] ?? snapshot.sharedPins
            change(&pins)
            snapshot.perDisplayPins[displayUUID] = pins
        } else {
            change(&snapshot.sharedPins)
        }
        save()
    }

    private func updateSavedLocation(ofIdentifier identifier: String, to url: URL) {
        var didChange = false

        func update(_ pins: inout [PinnedApp]) {
            for index in pins.indices
            where pins[index].bundleIdentifier == identifier && pins[index].bundleURL != url {
                pins[index].bundleURL = url
                didChange = true
            }
        }

        update(&snapshot.sharedPins)
        for displayUUID in Array(snapshot.perDisplayPins.keys) {
            update(&snapshot.perDisplayPins[displayUUID, default: []])
        }

        if didChange {
            save()
        }
    }

    private func save() {
        storage.save(snapshot)
    }
}
