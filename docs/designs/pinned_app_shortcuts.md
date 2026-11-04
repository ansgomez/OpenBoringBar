# Pinned App Shortcuts

*   **Author:** Andres Gomez
*   **Status:** Proposed
*   **Date:** 2026-11-03

--------------------------------------------------------------------------------

## Overview

OpenBoringBar draws a bar along the bottom of each display that lists the apps
currently running on that display. This design adds a short row of pinned app
icons at the left end of that bar. Clicking a pinned icon opens the app, or
switches to it if it is already running. The user picks which apps to pin from
the bar's right-click menus, and the list is saved between launches.

## The Problem

The bar only lists running apps. To open an app that is closed, the user has to
leave the bar and use the Dock, Launchpad, Spotlight, or Finder. People who keep
the Dock hidden because they use OpenBoringBar instead lose their one-click
launcher. The goal is to give back one-click launching for a few commonly used
apps without turning the bar into a full Dock.

The proposed fix is a pinned strip: icons only, no names, set apart from the
running-app pills by a thin divider. It sits outside the running-app list, so
the existing per-display app tracking and ordering does not change.

## Goals

*   The user can open any pinned app with one click on the bar, whether the
    app is running or not.
*   A running pinned app shows a running indicator (a dot under its icon).
*   The user can pin a running app from its pill's right-click menu.
*   The user can pin an app that is not running from the bar's right-click
    menu, using the existing installed-app search list.
*   The user can unpin an app from the pinned icon's right-click menu.
*   Pins keep the order they were added in and are still there after the app
    quits and relaunches.
*   When nothing is pinned, the bar looks and behaves exactly as it does today.

## Non-Goals

*   Reordering pins by dragging.
*   A clock, date, Trash, Downloads, or any other right-hand section.
*   Visual restyling of the bar (dark-mode colors, Liquid Glass, icon size).
*   Per-app actions beyond pin and unpin (Quit, Hide, New Window).
*   Merging pinned and running apps into one Dock-style row, or hiding the pill
    of a running pinned app.
*   Pinning files, folders, or URLs. Only `.app` bundles can be pinned.
*   Syncing pins across Macs.

## Open Questions

*   **Removable drives**: An app on an external drive that is unplugged when
    OpenBoringBar starts cannot be resolved and is dropped (see Pin
    Resolution). Accepted for now; listed so it is not re-asked.

## Critical User Journeys (CUJs)

### CUJ 1: Pin a running app and launch it later

*   **Given**: Safari is running and has a pill on the bar. Nothing is pinned.
*   **When**: The user right-clicks Safari's pill, chooses "Pin to Bar", quits
    Safari, then clicks the Safari pin.
*   **Then**: A Safari icon appears at the left end of every bar, followed by a
    divider. After Safari quits, the icon stays and its running dot goes away.
    Clicking it launches Safari and the dot comes back.

### CUJ 2: Pin an app that is not running

*   **Given**: Notes is installed and not running.
*   **When**: The user right-clicks an empty part of the bar, chooses "Add
    Shortcut…", types "notes" in the search list, and selects Notes.
*   **Then**: A Notes pin appears after any existing pins.

### CUJ 3: Unpin

*   **Given**: Notes is pinned.
*   **When**: The user right-clicks the Notes pin and chooses "Unpin".
*   **Then**: The pin disappears. If it was the last pin, the divider also
    disappears and the bar looks as it does today.

### CUJ 4: Pins survive a restart and an app move

*   **Given**: Safari and a third-party app `Foo.app` in `~/Downloads` are
    pinned.
*   **When**: The user moves `Foo.app` to `/Applications`, then quits and
    relaunches OpenBoringBar.
*   **Then**: Both pins are still there, in the same order. Clicking Foo opens
    the copy in `/Applications`.

### CUJ 5: Change which bars show pins

*   **Given**: Two displays, mode "All Displays", Safari and Notes pinned.
*   **When**: The user picks "Each Display Separately" from the bar's
    right-click menu, then unpins Notes on the second display.
*   **Then**: Both displays start with Safari and Notes. After the unpin, the
    second display shows only Safari and the first still shows both. Switching
    back to "All Displays" shows Safari and Notes on both bars again.

## Technical Plan (Architecture)

### Where pins live in the code

Pins are kept outside the running-app list. The running-app list is built per
display from on-screen windows (`BarDisplayStateBuilder`) and has its own
stable-order logic (`BarDisplayAppOrderManager`). Pins do not touch either.
A new store owns the pin data and its saved copy; `BarManager` turns stored
pins into display-ready items for each bar during its existing refresh.

```text
           UserDefaults (JSON)
                 ▲   │ load / save
                 │   ▼
          ┌──────────────────┐   pins + mode changed
          │  PinnedAppStore  │ ─────────────────────────┐
          └──────────────────┘                          │
             ▲ pin / unpin / setMode                    ▼
             │                              ┌──────────────────────┐
             │                              │      BarManager      │
             │                              │ refreshDisplayStates │
             │                              │ + running-app lookup │
             │                              └──────────────────────┘
             │                                          │ DisplayState
             │                                          │ (.apps, .pinnedApps)
             │                                          ▼
   ┌──────────────────────┐   actions        ┌──────────────────────┐
   │ DisplayPanelController│ ◄────────────── │ DisplayBottomBarView │
   │  (one panel/display)  │ ──────────────► │  pin strip │ pills   │
   └──────────────────────┘   state          └──────────────────────┘
```

Existing workspace observers in `BarManager` (launch, terminate, activate,
hide, unhide, space change) already schedule a refresh, so running dots update
without new observers. A change in the store also schedules a refresh.

### Data model

*   **`PinnedApp`** (saved): `bundleIdentifier` (optional string) and
    `bundleURL` (last known location). Two pins are the same app when their
    identifiers match, or, if either has no identifier, when their locations
    match. Pinning an app that is already pinned on the same list does
    nothing.
*   **`PinDisplayMode`** (saved): `allDisplays` (default), `mainDisplayOnly`,
    `perDisplay`. Shown in the bar's right-click menu as "Show Pins On" with
    "All Displays", "Main Display Only", and "Each Display Separately".
*   **Saved lists**: one shared list, used by `allDisplays` and
    `mainDisplayOnly`, and a map from display key to list, used by
    `perDisplay`. Both are kept at all times; switching modes never deletes a
    list.
*   **`PinnedAppItem`** (display only, not saved): pin identity, resolved
    location, name, icon, and the process ID of the running copy if any.
    Added to `DisplayState` as `pinnedApps`.
*   **`RunningAppItem`** gains `bundleIdentifier` and `bundleURL`, read from
    `NSRunningApplication`, so a pill can be pinned.

### Pin resolution (ID first)

Run when the store loads and before each launch:

1.  If the saved location exists and the bundle there has the saved
    identifier (or the pin has no identifier), use it.
2.  Otherwise, if the pin has an identifier, ask macOS for an app with that
    identifier (`NSWorkspace.urlForApplication(withBundleIdentifier:)`). If
    found, use it and save the new location.
3.  Otherwise the pin cannot be resolved. At load it is dropped from the saved
    list. At click time it is dropped and nothing launches.

### Running check

A pin counts as running when `NSWorkspace.shared.runningApplications` has an
app with the same identifier, or, for pins without one, the same bundle
location. This uses every running app, not just the apps shown on that
display's bar, because the bar only lists apps with windows on its display.

### Click behavior

*   **Running**: call `BarManager.activate(processID:minimizeIfFrontmost:)`
    with `minimizeIfFrontmost: false`. It is the same path a pill click uses
    (unhide, restore a minimized window, activate), except that it never
    minimizes. Clicking the pin of the app already in front does nothing.
    Pill clicks keep today's behavior (`minimizeIfFrontmost` defaults to
    `true`).
*   **Not running**: resolve the pin, then call the existing
    `BarManager.openApplication(bundleURL:)`.

### Which pins each bar shows

*   **`allDisplays`**: every bar shows the shared list.
*   **`mainDisplayOnly`**: the main display's bar (the screen with the menu
    bar, `NSScreen.screens.first`) shows the shared list; other bars show no
    pins and no divider. "Pin to Bar" on another bar still adds to the shared
    list.
*   **`perDisplay`**: each bar shows its display's own list. The display key
    is the display's UUID (`CGDisplayCreateUUIDFromDisplayID`), not its
    numeric `CGDirectDisplayID`, because the numeric ID can change when a
    monitor is reconnected or moved to another port. A display that has no
    list yet starts with a copy of the shared list. Lists of disconnected
    displays are kept, so they come back when the monitor is reconnected.

Pin, unpin, and "Add Shortcut…" act on the list that the bar being clicked is
showing.

### Bar layout

*   Left to right: pin strip, divider, running-app pills (unchanged).
*   Pin icons are the same size as pill icons (18 pt) in a 28 pt square hit
    area, with a 4 pt running dot below the icon. The pin's name shows as a
    tooltip.
*   The strip takes the width it needs, up to 40% of the bar. Past that, the
    strip scrolls sideways, as the running-app list already does.
*   With no pins on a bar, the strip and divider are not drawn at all.

### Menus

*   **Pill right-click (new)**: "Pin to Bar", or "Unpin from Bar" if that app
    is already on this bar's list.
*   **Pin right-click (new)**: "Unpin".
*   **Bar right-click (existing, extended)**: Quit, Auto-collapse (existing),
    then "Add Shortcut…" and the "Show Pins On" picker. "Add Shortcut…" opens
    the existing `ApplicationLauncherPopoverView` list, anchored to the left
    end of the bar; picking an app pins it and closes the list.

## Alternatives Considered

### Alternative A: Pop-up grid behind a bar button

A single button in the bar opens a floating grid of pinned apps with a search
field.

*   **Pros**: Uses almost no bar width. The search field could launch any
    installed app, not only pinned ones.
*   **Cons**: Every launch takes two clicks instead of one. The pins are not
    visible until the grid is opened, so the user cannot see at a glance which
    pinned apps are running.
*   **Reason for Rejection**: The point of the feature is one-click launching
    of a few apps. A second click per launch defeats it.

### Alternative B: Merged row, like the Dock

Pinned and running apps share one row. Pinned apps that are not running are
drawn dimmed in the same row.

*   **Pros**: Closest to the Dock. A running pinned app appears once, which
    saves width.
*   **Cons**: The running-app row is built per display from on-screen windows,
    with its own stable-order logic. Mixing pins into it means changing that
    logic, deciding where a pin goes when its app has windows on another
    display, and handling the order when apps launch and quit.
*   **Reason for Rejection**: Most work and most risk to existing behavior,
    for a width saving the user did not ask for.

### Alternative C: Identify pins by file location only

*   **Pros**: Least code. Works for every app, including ones without an
    identifier, and tells two copies of the same app apart.
*   **Cons**: A pin breaks when the app is moved, renamed, or reinstalled to a
    new location.
*   **Reason for Rejection**: Moving an app (for example from `~/Downloads` to
    `/Applications`) is common, and losing the pin then is a visible failure.

### Alternative D: Identify pins by app identifier only

*   **Pros**: Survives moves and renames. Matches running apps directly.
*   **Cons**: Apps without an identifier cannot be pinned. With two copies
    that share an identifier (for example two Xcode versions), macOS picks
    which copy opens.
*   **Reason for Rejection**: The chosen approach (identifier first, location
    as fallback and tie-breaker) keeps these benefits and covers both gaps,
    at the cost of a short resolution step.

### Alternative E: One fixed display rule instead of a setting

Always show the same pins on every bar, with no setting.

*   **Pros**: Smallest change; no per-display storage.
*   **Cons**: No way to keep secondary displays free of pins, or to have
    different pins per screen.
*   **Reason for Rejection**: The user asked for the display rule to be
    configurable, with all three modes. "All Displays" stays the default.

### Alternative F: Key per-display pins by numeric display ID

*   **Pros**: The numeric ID (`CGDirectDisplayID`) is what the code already
    uses for each panel, so no conversion is needed.
*   **Cons**: The numeric ID can change when a monitor is reconnected or moved
    to another port, which would orphan that display's pins.
*   **Reason for Rejection**: The display UUID stays the same in more of those
    cases. The code converts the numeric ID to a UUID only when reading or
    writing per-display lists.

--------------------------------------------------------------------------------

## Non-Functional Requirements

*   **Performance**: Pin items are rebuilt on every bar refresh (already
    debounced to 0.1 s). Icons are cached by bundle location in `BarManager`
    so a refresh does not reload icons from disk. Resolution with
    `NSWorkspace.urlForApplication(withBundleIdentifier:)` runs only at load
    and at click time, not on refresh.
*   **Storage**: One JSON value in `UserDefaults`, a few hundred bytes per
    pin. A version number in the saved value lets a later format change
    detect old data.
*   **Rollback**: Removing the feature leaves an unused `UserDefaults` key;
    nothing else changes.

### Future Improvements

*   **Drag to reorder pins**: out of scope here; the saved list is already
    ordered, so only the view needs to change.
*   **Removable drives**: keep unresolved pins hidden instead of dropping
    them, so apps on an unplugged drive come back.
*   **One icon per running pinned app**: hide the pill of a running pinned
    app (Alternative B's width saving) behind a setting.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

All paths are relative to the repository root. New Swift files under
`OpenBoringBar/App/` and `OpenBoringBar/Core/` are picked up by the project
generator's existing globs. Test files are picked up by a new glob (item 14).
Re-run `pod install` (or `./scripts/bootstrap.sh`) after adding files.

### Target Files to Create/Modify

#### 1. `OpenBoringBar/Core/Domain/Models/PinnedAppModels.swift` (Create)

*   **Type / Scope**: Swift models.
*   **Proposed Changes**:
    *   `struct PinnedApp: Codable, Hashable` with `bundleIdentifier: String?`
        and `bundleURL: URL`.
    *   `enum PinDisplayMode: String, Codable, CaseIterable` with
        `allDisplays`, `mainDisplayOnly`, `perDisplay`, and a `menuTitle`
        ("All Displays", "Main Display Only", "Each Display Separately").
    *   `struct PinnedAppItem: Identifiable, Hashable` (display only):
        `pin: PinnedApp`, `name: String`, `runningProcessID: pid_t?`;
        `id` is the identifier if present, else the location path.
    *   `struct PinnedAppsSnapshot: Codable` (saved form): `version: Int`
        (= 1), `mode: PinDisplayMode`, `sharedPins: [PinnedApp]`,
        `perDisplayPins: [String: [PinnedApp]]` keyed by display UUID string.

#### 2. `OpenBoringBar/Core/Bar/PinnedAppMatcher.swift` (Create)

*   **Type / Scope**: Pure functions, no AppKit state; unit-tested.
*   **Proposed Changes**:
    *   `static func isSameApp(_ a: PinnedApp, _ b: PinnedApp) -> Bool`:
        identifiers equal when both present; otherwise standardized locations
        equal.
    *   `static func runningProcessID(for pin: PinnedApp, in running:
        [RunningAppDescriptor]) -> pid_t?` where `RunningAppDescriptor` is
        `(processID, bundleIdentifier?, bundleURL?)`. Same matching rule.
        Returns the first match.

#### 3. `OpenBoringBar/Core/Infrastructure/Application/ApplicationLocator.swift` (Create)

*   **Type / Scope**: Protocol plus AppKit implementation.
*   **Proposed Changes**:
    *   `protocol ApplicationLocating` with `fileExists(at: URL) -> Bool`,
        `bundleIdentifier(at: URL) -> String?`, and
        `applicationURL(forBundleIdentifier: String) -> URL?`.
    *   `final class WorkspaceApplicationLocator: ApplicationLocating` using
        `FileManager`, `Bundle(url:)?.bundleIdentifier`, and
        `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`.
    *   Exists so the store's resolution logic can be tested with a fake.

#### 4. `OpenBoringBar/Core/Infrastructure/Persistence/PinnedAppStorage.swift` (Create)

*   **Type / Scope**: Protocol plus `UserDefaults` implementation.
*   **Proposed Changes**:
    *   `protocol PinnedAppStoring` with `load() -> PinnedAppsSnapshot?` and
        `save(_: PinnedAppsSnapshot)`.
    *   `final class UserDefaultsPinnedAppStorage` storing JSON under the key
        `OpenBoringBar.pinnedApps` (same prefix as the existing
        `OpenBoringBar.autoCollapseEnabled`). A value that fails to decode, or
        has an unknown `version`, is treated as empty and logged with
        `NSLog`; it is overwritten on the next save.

#### 5. `OpenBoringBar/Core/Bar/PinnedAppStore.swift` (Create)

*   **Type / Scope**: `ObservableObject`; owns all pin state; unit-tested.
*   **Proposed Changes**:
    *   `init(storage: PinnedAppStoring, locator: ApplicationLocating)`.
        Loads the snapshot, resolves every pin (rules below), drops pins that
        do not resolve, saves if anything changed.
    *   `@Published private(set) var mode: PinDisplayMode` (default
        `allDisplays`).
    *   `func pins(forDisplayUUID: String?, isMainDisplay: Bool) ->
        [PinnedApp]`:
        *   `allDisplays` → shared list.
        *   `mainDisplayOnly` → shared list if `isMainDisplay`, else `[]`.
        *   `perDisplay` → that display's list; if the display has no list
            yet, or the UUID is `nil`, the shared list.
    *   `func pin(_ app: PinnedApp, displayUUID: String?)`,
        `func unpin(_ app: PinnedApp, displayUUID: String?)`,
        `func isPinned(_ app: PinnedApp, displayUUID: String?,
        isMainDisplay: Bool) -> Bool`, `func setMode(_: PinDisplayMode)`.
        In `perDisplay` mode, the first pin or unpin on a display with no
        list copies the shared list to it, then applies the change. In the
        other modes, pin and unpin edit the shared list. Pin is a no-op if
        `PinnedAppMatcher.isSameApp` finds the app in the target list. Every
        change saves immediately and publishes.
    *   `func resolve(_ pin: PinnedApp) -> PinnedApp?` (rules from the
        Technical Plan): use the saved location if it exists and its
        identifier matches (or the pin has none); else look up by identifier;
        else `nil`. When the location changes, the stored pin is updated and
        saved.

#### 6. `OpenBoringBar/Core/Infrastructure/Screen/NSScreen+DisplayID.swift` (Modify)

*   **Type / Scope**: Extension.
*   **Proposed Changes**: Add `static func displayUUIDString(for:
    CGDirectDisplayID) -> String?` using `CGDisplayCreateUUIDFromDisplayID`
    and `CFUUIDCreateString`. Needed for per-display keys.

#### 7. `OpenBoringBar/Core/Domain/Models/BarModels.swift` (Modify)

*   **Type / Scope**: Swift models.
*   **Proposed Changes**:
    *   `RunningAppItem` gains `bundleIdentifier: String?` and
        `bundleURL: URL?`, so a pill can be pinned.
    *   `DisplayState` gains `displayUUID: String?`, `isMainDisplay: Bool`,
        and `pinnedApps: [PinnedAppItem]`.

#### 8. `OpenBoringBar/Core/Bar/BarDisplayStateBuilder.swift` (Modify)

*   **Type / Scope**: Display state construction.
*   **Proposed Changes**:
    *   When mapping snapshots to `RunningAppItem`, read
        `NSRunningApplication(processIdentifier:)` for `bundleIdentifier` and
        `bundleURL`.
    *   `buildDisplayStates` takes a new parameter
        `pinnedAppsForDisplay: (String?, Bool) -> [PinnedAppItem]` and fills
        `displayUUID` (item 6), `isMainDisplay` (`screen ==
        NSScreen.screens.first`), and `pinnedApps` for each display. The
        running-app ordering code is not changed.

#### 9. `OpenBoringBar/Core/Bar/BarManager.swift` (Modify)

*   **Type / Scope**: Coordinator.
*   **Proposed Changes**:
    *   `init` takes `pinnedAppStore: PinnedAppStore` (default built with
        `UserDefaultsPinnedAppStorage` and `WorkspaceApplicationLocator`) and
        subscribes to its `objectWillChange` to call `scheduleDisplayRefresh`.
    *   `refreshDisplayStates` builds one `[RunningAppDescriptor]` from
        `NSWorkspace.shared.runningApplications` and passes a closure to the
        builder that maps the store's pins to `PinnedAppItem`s using
        `PinnedAppMatcher.runningProcessID` and the app's display name
        (`FileManager.displayName(atPath:)` without `.app`).
    *   `func icon(for url: URL) -> NSImage` with a dictionary cache, used by
        the view.
    *   `activate(processID:)` becomes `activate(processID:,
        minimizeIfFrontmost: Bool = true)`. When `false`, the "already in
        front → minimize focused window" branch is skipped. Existing callers
        are unchanged.
    *   New actions: `openPinnedApp(_ item: PinnedAppItem)` (running →
        `activate(processID:minimizeIfFrontmost: false)`; else `store.resolve` then
        `openApplication(bundleURL:)`; unresolved → `store.unpin` from every
        list), `pin(runningApp:displayUUID:)`,
        `pin(launchable:displayUUID:)`, `unpin(_:displayUUID:)`,
        `setPinDisplayMode(_:)`, and a read-only `pinDisplayMode`.

#### 10. `OpenBoringBar/Core/Application/AppRuntimeCoordinator.swift` (Modify)

*   **Type / Scope**: App wiring.
*   **Proposed Changes**: None beyond what the `BarManager` default argument
    provides; listed because `BarManager(eventBus:)` is constructed here
    (line 21) and must still compile. Change only if the default argument is
    removed.

#### 11. `OpenBoringBar/Core/DisplayBar/DisplayPanelController.swift` (Modify)

*   **Type / Scope**: Panel wiring.
*   **Proposed Changes**: `updateContent` passes the full `DisplayState`
    pin fields and new closures to `DisplayBottomBarView`: `onOpenPinned`,
    `onPinRunningApp`, `onPinLaunchable`, `onUnpin` (each bound to this
    display's UUID), `pinDisplayMode`, `onPinDisplayModeChanged`, and
    `iconForURL`.

#### 12. `OpenBoringBar/Core/DisplayBar/DisplayBottomBarView.swift` (Modify)

*   **Type / Scope**: SwiftUI view.
*   **Proposed Changes**:
    *   New private `DisplayBarPinnedStrip` view: a horizontal row of
        `DisplayBarPinnedIcon` (18 pt icon in a 28 pt square, 4 pt dot below
        when `runningProcessID != nil`, `.help(name)` tooltip, right-click
        "Unpin"). Width capped at 40% of the bar with
        `ViewThatFits`/`GeometryReader`; scrolls sideways past that.
    *   Before the running-app `Group`: the strip and a `Divider` (same
        vertical padding as the commented-out launcher divider), both drawn
        only when `pinnedApps` is non-empty.
    *   `DisplayBarAppPill` gains a `.contextMenu` with "Pin to Bar" or
        "Unpin from Bar", based on an `isPinned` flag passed in. Pills of
        apps without a `bundleURL` show no pin item.
    *   Bar `.contextMenu` adds "Add Shortcut…" and a "Show Pins On"
        `Picker` (inline menu style) after the existing items.
    *   "Add Shortcut…" sets the existing `isApplicationLauncherPresented`
        state; the popover with `ApplicationLauncherPopoverView` is attached
        to a zero-size view at the leading edge. Selecting an app calls
        `onPinLaunchable` instead of `onOpenApplication`, then closes the
        popover.

#### 13. `OpenBoringBar/Core/DisplayBar/ApplicationLauncherPopoverView.swift` (Modify)

*   **Type / Scope**: SwiftUI view.
*   **Proposed Changes**: Add a `title: String` parameter (default
    "Applications") so the pin flow can show "Add Shortcut". No other
    behavior change.

#### 14. `scripts/generate_xcodeproj.rb` (Modify)

*   **Type / Scope**: Project generator (Ruby, `xcodeproj` gem).
*   **Proposed Changes**:
    *   Add a `:unit_test_bundle` target `OpenBoringBarTests` (macOS 14.0)
        with sources from `OpenBoringBarTests/**/*.swift`, `TEST_HOST` and
        `BUNDLE_LOADER` pointing at the app binary, a dependency on the app
        target, and `GENERATE_INFOPLIST_FILE = YES`.
    *   Set `ENABLE_TESTABILITY = YES` on the app's Debug configuration.
    *   Write a shared scheme `OpenBoringBar` (`Xcodeproj::XCScheme`) whose
        build action has the app and whose test action has
        `OpenBoringBarTests`, so `xcodebuild test -scheme OpenBoringBar`
        works on a freshly generated project.

#### 15. `OpenBoringBarTests/PinnedAppStoreTests.swift` (Create)

*   **Type / Scope**: XCTest unit tests, with `FakePinnedAppStorage` and
    `FakeApplicationLocator` defined in the same file.
*   **Proposed Changes**: Test cases:
    *   Empty storage → mode `allDisplays`, no pins.
    *   Pin, then reload from the same fake storage → same pins, same order.
    *   Pinning a duplicate (same identifier, different location) → no-op.
    *   Resolution: saved location valid → kept; location missing but
        identifier found → new location stored and saved; both missing →
        dropped at load; no identifier and location missing → dropped.
    *   Location exists but holds a different identifier → falls back to
        lookup by identifier.
    *   `mainDisplayOnly` → main display gets shared list, other gets `[]`.
    *   `perDisplay`: display without a list sees shared list; first unpin on
        it copies then removes; other display and shared list unchanged;
        switching back to `allDisplays` shows the untouched shared list.
    *   `nil` display UUID in `perDisplay` → shared list.
    *   Undecodable stored data and unknown `version` → empty store, no crash.

#### 16. `OpenBoringBarTests/PinnedAppMatcherTests.swift` (Create)

*   **Type / Scope**: XCTest unit tests.
*   **Proposed Changes**: Same identifier with different locations → same
    app; no identifier with same location → same app; one with and one
    without identifier, same location → same app; different identifiers with
    same location → different apps; `runningProcessID` returns the matching
    process or `nil`.

#### 17. `scripts/bootstrap.sh` (Modify)

*   **Type / Scope**: Build script.
*   **Proposed Changes**: Add step "3/3 xcodebuild test" running the
    `OpenBoringBar` scheme with the same derived-data path. Update step
    labels from "1/2", "2/2" to "1/3", "2/3".

#### 18. `README.md` (Modify)

*   **Type / Scope**: Documentation.
*   **Proposed Changes**: Add a short "Pinned apps" section (how to pin,
    unpin, and change "Show Pins On") and the `xcodebuild test` command
    under "Manual Commands".

#### 19. `docs/designs/pinned_app_shortcuts.md` (Create, at finalization)

*   **Type / Scope**: Design document.
*   **Proposed Changes**: Final copy of this draft (Step 6 of the EGM draft
    flow). `design_draft.md` and `discussion_summary.md` are deleted after
    the final copy is written; they are never committed.

### Verification Plan

*   **Compilation/Build**: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    ./scripts/bootstrap.sh` (generates the project, builds, runs tests).
*   **Unit Tests**: `xcodebuild test -project OpenBoringBar.xcodeproj -scheme
    OpenBoringBar -destination 'platform=macOS'`. All cases in items 15 and
    16 pass.
*   **Static Analysis & Linting**: None configured in the repository; build
    with zero new compiler warnings.
*   **Test Coverage Requirement**: Every public method of `PinnedAppStore`
    and `PinnedAppMatcher` has at least one test. UI code is not
    unit-tested.
*   **E2E/Integration**: Copy the Debug build to `~/Applications`, re-grant
    permissions if asked, and walk through CUJs 1–5 by hand on two displays
    (CUJ 5 needs a second display). Also check: with no pins the bar looks
    as before; a pinned app that is running on another display shows its dot;
    clicking the pin of the app already in front does not minimize it, while
    clicking its pill still does.

--------------------------------------------------------------------------------

<!-- Provenance: Indicates initial structural drafting via EGM. -->

*Drafted with EGM*
