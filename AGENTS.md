# OpenBoringBar Agent Guide

> AI collaboration entry for OpenBoringBar.
> Goal: deliver a stable bottom taskbar experience for multi-display macOS users in a transparent and contributor-friendly codebase.

## Mission

OpenBoringBar is an open-source implementation inspired by [boringbar.app](https://boringbar.app).
Priority is reliability of core behavior before visual polish.

## Product Direction

1. Keep focus on BoringBar-like core workflow:
   - per-display bars
   - running app visibility
   - app switching
2. Optimize for real usability and stability first.
3. Build in public so contributors can inspect and extend behavior.

## Technical Baseline

1. Platform: `macOS 14+`
2. Language: `Swift 5`
3. UI stack: `SwiftUI` + `AppKit` + `ApplicationServices`
4. Project generation: `CocoaPods` (`pod install` maintains project/workspace)

## Repository Structure

```text
.
├── OpenBoringBar/
│   ├── App/
│   ├── Core/
│   │   ├── Application/
│   │   ├── Bar/
│   │   ├── DisplayBar/
│   │   ├── Domain/Models/
│   │   └── Infrastructure/
│   └── Resources/
├── OpenBoringBarTests/
├── scripts/
│   ├── bootstrap.sh
│   ├── generate_xcodeproj.rb
│   ├── install.sh
│   ├── OpenBoringBar.entitlements
│   └── layouts/
├── docs/
├── .agents/
│   ├── AGENTS.md
│   ├── skills/
│   ├── rules/
│   ├── mappings/
│   ├── docs/ai/
│   ├── checklists/
│   ├── templates/
│   └── examples/
└── AGENTS.md
```

## .agents Knowledge Base

Use `.agents/` as the practical operating handbook.

1. `rules/`: hard boundaries and coding constraints
2. `skills/`: executable workflows (delivery/build/regression)
3. `mappings/`: machine-readable ownership and validation mapping
4. `docs/ai/`: deeper technical notes and troubleshooting
5. `checklists/`: done criteria
6. `templates/`: feature spec and PR summary templates
7. `examples/`: concrete handoff examples

Recommended read order:

1. `AGENTS.md` (this file)
2. `.agents/rules/*.md`
3. `.agents/skills/feature-delivery.md`
4. `.agents/skills/build-and-validate.md`
5. `.agents/checklists/change-done-checklist.md`

## Core Commands

```bash
# Full bootstrap + build + unit tests (required after every code change)
./scripts/bootstrap.sh

# Install the Debug build to ~/Applications with a stable signature, relaunch
./scripts/install.sh

# Regenerate Xcode project from source globs (only when needed)
ruby scripts/generate_xcodeproj.rb
pod install

# Manual build command
xcodebuild \
  -project OpenBoringBar.xcodeproj \
  -scheme OpenBoringBar \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build

# Unit tests (same flags, `test` action)
xcodebuild -project OpenBoringBar.xcodeproj -scheme OpenBoringBar \
  -configuration Debug -sdk macosx -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData test
```

## Current Architecture (Must Follow)

Current source layout:

```text
OpenBoringBar/
  App/
    OpenBoringBarApp.swift
    PermissionManager.swift
    PermissionSetupView.swift
  Core/
    Application/
      AppRuntimeCoordinator.swift
      AppEventBus.swift
    Bar/
      BarAccessibilityObserverManager.swift
      BarAppSnapshot.swift
      BarDisplayAppOrderManager.swift
      BarDisplayStateBuilder.swift
      BarManager.swift
      ActiveWindowBottomGuardManager.swift
      BarLayoutConstants.swift
      PinnedAppManager.swift
      PinnedAppMatcher.swift
    DisplayBar/
      AppWindowPreviewPanelView.swift
      AppWindowPreviewPanelWindow.swift
      ApplicationLauncherPopoverView.swift
      DisplayPanelController.swift
      DisplayBottomBarView.swift
    Domain/
      Models/
        AppWindowPreviewItem.swift
        BarModels.swift
        LaunchableApplicationItem.swift
        PinDisplayMode.swift
        PinMove.swift
        PinnedApp.swift
        PinnedAppItem.swift
        PinnedAppsSnapshot.swift
        RunningAppDescriptor.swift
    Infrastructure/
      Application/
        ApplicationLocationProvider.swift
        DockNotificationBadgeProvider.swift
        InstalledApplicationProvider.swift
        WindowPreviewProvider.swift
      Persistence/
        PinnedAppStorageProvider.swift
      Accessibility/
        AXElementInspector.swift
      Screen/
        NSScreen+DisplayID.swift
  Resources/
    Assets.xcassets/
      AppIcon.appiconset/
    Info.plist
OpenBoringBarTests/
  PinnedAppManagerTests.swift
  PinnedAppMatcherTests.swift
  PinnedAppStorageProviderTests.swift
  PinnedAppTestDoubles.swift
```

### Unit Tests

1. `OpenBoringBarTests` is a hostless unit-test bundle: it has no `TEST_HOST`
   and compiles the app sources it tests directly, listed in
   `APP_SOURCES_UNDER_TEST` in `scripts/generate_xcodeproj.rb`. Running tests
   never launches the bar app.
2. Only add sources without app-wide side effects to that list. Inject
   system access through protocols (for example `ApplicationLocating`,
   `PinnedAppStoring`) and use fakes in tests.
3. The generator saves a shared `OpenBoringBar` scheme whose test action runs
   this bundle.

### Pinned Apps

1. `PinnedAppManager` (`Core/Bar`) owns pin state and saves it through
   `PinnedAppStoring` as JSON under `OpenBoringBar.pinnedApps`.
2. `BarManager` attaches pins to each `DisplayState` after
   `BarDisplayStateBuilder` runs, and calls `scheduleDisplayRefresh()` after
   each pin change. Pin traffic stays inside `Core/Bar`, so it adds no
   `AppEvent` cases.
3. Pins are never deleted automatically; unresolved pins are kept and hidden.
   Idle pins (app not running) are drawn as a folded diagonal stack at the
   far left; `FoldedStackLayout` (`Core/Bar`, pure, unit-tested) holds the
   rules and geometry, `DisplayBarPinnedStrip` draws it. Resting the
   pointer on the stack (`hoverIntentDelay`) unfolds it; leaving the strip
   folds it. Move Left/Right act within the pin's drawn group
   (`FoldedStackLayout.moveGroup`, used by the view and `BarManager.movePin`).
   Running regular apps that match no pin of the bar follow the pins in the
   strip (`DisplayState.runningUnpinnedApps`, `PinnedAppItem.isPinned` false,
   chosen by `PinnedAppMatcher.unpinnedRunningApps`).
4. Pin click with AeroSpace never leaves the workspace shown on the clicked
   bar: `PinClickRule` (`Core/Bar`, pure, unit-tested) returns a
   `PinClickAction`: focus the app's window there, open a new one, or
   `.activate` when AeroSpace reports no workspace (not running, failed
   read). Shift-click and the "New Window" menu items always open a new one.
5. New windows: `AppNewWindowProvider` (`Core/Infrastructure/Accessibility`)
   presses the app's own menu item through AX without activating the app
   (activation makes AeroSpace jump to the app's existing window);
   `NewWindowMenuItemRule` (`Core/Bar`, pure, unit-tested) picks the item.
   `AeroSpaceWorkspaceManager.focusNewWindow` then waits for the window, moves
   it to the target workspace if needed and focuses it. `BarManager` falls
   back to `activate(processID:)` when no item or no window is found.
   A plain click passes `isExplicitRequest: false`, which limits the
   Command-N fallback to document titles ("New", "New Document", "New File")
   so it cannot create notes, events or messages. `BarManager` allows one
   new-window request per app at a time (`openingNewWindowProcessIDs`).

### Start Menu

1. `StartMenuBuilder` (`Core/DisplayBar`) builds the menu at click time:
   frequently used apps, all apps and the Applications folder (the latter via
   `FolderPeekMenuBuilder`), the peek folders flagged `isInStartMenu`
   (`FolderPeekManager.startMenuFolders`; the bar shows `barFolders`), and
   workspace layout scripts.
2. `AppUsageManager` (`Core/Bar`) counts app activations (called from
   `BarManager`'s activation observer) and saves them through
   `AppUsageStoring` under `OpenBoringBar.appUsage`; `AppUsageCalculator`
   holds the decay and ranking math (pure, unit-tested). With nothing saved,
   `SpotlightUsageProvider` seeds the records once. The list is the 10 most
   used apps plus every pin of that bar, minus the apps the user removed
   (`AppUsageSnapshot.hiddenBundleIdentifiers`; right-click an item in the
   menu, handled in `StartMenuBuilder` by checking the click's event).
   Favorites (`AppUsageSnapshot.favoriteBundleIdentifiers`, in the order
   added) come from "Add to Start Menu" in the context menu of a pin, a
   running icon or a pill; they are listed first and left out of the
   frequent list.
3. Workspace layouts: `WorkspaceLayoutProvider`
   (`Core/Infrastructure/Application`) lists and runs the executables in
   `~/.config/openboringbar/layouts`; the bar passes the workspace name as the
   argument. Layout logic lives in the scripts (`scripts/layouts/`), not in
   the app. Scripts may send Apple Events, which is why `scripts/install.sh`
   signs with `scripts/OpenBoringBar.entitlements` and `Info.plist` has
   `NSAppleEventsUsageDescription`.

### Folder Widgets

1. `FolderPeekManager` (`Core/Bar`, `ObservableObject`) owns the folder list,
   saved through `PeekFolderStoring` under `OpenBoringBar.peekFolders`, and the
   Show Folders setting (`OpenBoringBar.showFolders`). With nothing saved, it
   imports from Folder Peek via `FolderPeekImporter` (read-only) or falls back
   to Downloads.
2. `FolderPeekMenuBuilder` (`Core/DisplayBar`) builds the folder menu at click
   time from `FolderContentsProvider` + `FolderEntrySorter`; subfolder menus
   fill lazily. `ClosureMenuItem` is shared by all click-time menus.

### System Stats Widgets

1. `SystemStatsProvider` (`Core/Infrastructure/System`) reads CPU ticks,
   VM statistics, the startup volume and IOKit power sources;
   `SystemStatsCalculator` (`Core/Bar`) holds the pure math (unit-tested).
2. `SystemStatsMonitor` (`Core/Bar`, `ObservableObject`) samples every 2 s off
   the main thread while enabled (`OpenBoringBar.showSystemStats`).
   `SystemStatsWidgetsView` observes it directly, so samples redraw only the
   widgets, not the whole bar.

### Background App

`Info.plist` sets `LSUIElement`: no Dock icon, no menu bar, not in
Command-Tab; Quit is in the bar's context menu. `OpenBoringBarApp` switches
to a regular app (and activates) only while the permission setup window is
shown, so that window can be found again.

### AeroSpace Integration

1. `AeroSpaceClient` (`Core/Infrastructure/Application`) is the only code that
   runs the `aerospace` CLI; `AeroSpaceOutputParser` turns its output into
   `AeroSpaceState` (`Core/Domain/Models`).
2. `AeroSpaceWorkspaceManager` (`Core/Bar`) owns the current state, re-reads
   it off the main thread (coalesced; on app activation, AX window changes,
   after commands, and every 2 s), and saves the Show Workspaces setting under
   `OpenBoringBar.showWorkspaces`. Empty reads (a failed CLI call) do not
   replace a good state for 3 s (`AeroSpaceStateRetentionRule`, unit-tested).
3. `BarManager` attaches `WorkspaceGroupBuilder` output to each
   `DisplayState`; `WorkspaceRowView` draws it inside the bar's single row
   (the panel is always `BarLayoutConstants.panelHeight` high). With Pills
   Follow Workspace, the group of the visible workspace holds the window
   pills in place of icons; otherwise the per-app pills follow the groups.
   Groups are in keyboard order (1–9, 0, then other names) and include empty
   workspaces only while Show Empty Workspaces
   (`OpenBoringBar.showEmptyWorkspaces`, default on) is set; the "+" drop
   target is only drawn when it is off.
4. Pills Follow Workspace (`OpenBoringBar.pillsFollowWorkspace`, default on):
   `BarManager` replaces `DisplayState.apps` with one `RunningAppItem` per
   window of the visible workspace (`windowID` set), ordered by
   `WorkspaceGroupBuilder.visibleWorkspaceWindows`; pill clicks with a
   `windowID` focus that window through AeroSpace. AeroSpace drops minimized
   windows from every workspace, so `AeroSpaceWorkspaceManager` remembers each
   window's last workspace (`lastKnownWorkspaceByWindowID`);
   `MinimizedWindowProvider` (AX, window IDs via `_AXUIElementGetWindow`) lists
   minimized windows and `WorkspaceGroupBuilder.minimizedWindows` places them as
   dimmed pills (`isMinimized`). Restoring focuses the remembered workspace
   first, because AeroSpace adds restored windows to the focused workspace.
   That placement is only used with the workspace groups hidden. With the
   groups shown, minimized windows are not tied to a workspace: they are
   drawn in a "–" group after the workspaces
   (`DisplayState.minimizedWindows`,
   `WorkspaceGroupBuilder.minimizedGroupWindows`). The group is the bar's
   own; AeroSpace has no such workspace and cannot hold minimized windows.
   The group follows Accessibility (which reports a minimize at once), not
   AeroSpace's list, plus the bar's own pending minimizes and restores
   (`BarManager.pendingMinimizedWindows`, `pendingRestoredWindowIDs`), so it
   does not wait for the next AeroSpace read.
   A click restores onto the workspace shown on that bar; a drop on the
   group minimizes the window (`aerospace macos-native-minimize`).
5. Folded pills: with the groups shown, `DisplayBarPillRow` keeps the full
   pill only for the focused window; the others are icon chips that overlap
   (`FoldedStackLayout.foldedFlags`, `runPositions`). Resting the pointer on
   a chip unfolds the row; leaving the row folds it. Nothing folds in a row
   without a focused window (for example the bar of the display that does
   not have focus). The row owns its unfolded state and is re-created per
   workspace.
6. Off-screen windows: `OffScreenWindowRule` hides pills for apps whose
   windows are all parked by AeroSpace; window cycling and the pill window
   menu deliberately ignore that rule.

## Layer Responsibilities

1. `App/`
   - App entry and top-level screen flow only.
   - No heavy AX/CGWindow business logic.
2. `Core/Application/`
   - Runtime orchestration and module wiring.
   - Coordinate feature managers through typed events/interfaces.
3. `Core/Bar/`
   - Core business behavior for app discovery, activation, ordering, window guard.
4. `Core/DisplayBar/`
   - Display panel/window lifecycle and bar rendering.
5. `Core/Domain/Models/`
   - Shared entities/value objects.
   - Keep dependency-light (`Foundation`/`CoreGraphics` preferred).
6. `Core/Infrastructure/`
   - System adapters/wrappers (`AX`, `NSScreen`, `CGWindowList`, etc.).
   - Reusable low-level helpers only.

## Dependency Direction

1. Allowed direction:
   `App -> Application -> (Bar/DisplayBar) -> Domain + Infrastructure`
2. `Domain` must not depend on `Application`, `Bar`, `DisplayBar`, or UI code.
3. `Infrastructure` must not depend on UI layer.
4. `DisplayBar` must not contain AX/CGWindow business policy.
5. Cross-module communication must prefer typed events (`AppEventBus`).

## Coding And Placement Conventions (Strict)

1. Shared models must live in `Core/Domain/Models/`.
2. One primary type per file; file name must match primary type.
3. Platform extensions in dedicated infra extension files.
4. Naming:
   - `*Coordinator`: orchestration
   - `*Manager`: long-lived behavior
   - `*Inspector` / `*Client` / `*Provider`: low-level helpers
5. Access control defaults to `private`/`fileprivate`.
6. UI-facing orchestration types should be `@MainActor`.
7. Timer/work item lifecycle must be explicitly cancelled in `deinit`.
8. New feature events must be typed `AppEvent` cases.
9. Reuse infrastructure helpers (for example `AXElementInspector`) when parsing AX/window attributes.
10. Shared constants belong in dedicated constant files.

## Standard Delivery Flow

```text
Phase 1: Boundary design
  pick layer + define events/models when cross-cutting

Phase 2: Implementation
  ship runnable behavior first, keep changes layered

Phase 3: Validation
  run ./scripts/bootstrap.sh
  run manual regression scenarios

Phase 4: Documentation sync
  update AGENTS.md + README.md when architecture/workflow conventions changed
```

Detailed playbooks:

- `.agents/skills/feature-delivery.md`
- `.agents/skills/build-and-validate.md`
- `.agents/skills/manual-regression.md`

## Validation Rules (Per Change)

After every code change:

1. Run `./scripts/bootstrap.sh` and resolve build issues.
2. Provide regression validation notes (at least manual verification steps).
3. Verify relevant scenarios:
   - permission setup flow
   - multi-display bar create/remove
   - app switch from capsule
   - launcher open/search/launch
   - bottom guard behavior for frontmost window
   - pinned apps (pin, open, unpin, Show Pins On modes)
   - pin click with AeroSpace (focus here, new window here, Shift-click)
   - Start menu (frequent apps, all apps, Applications folder, a layout)

## Documentation Freshness Policy (Strict)

1. Any architecture/structure/workflow convention update must update both:
   - `AGENTS.md`
   - `README.md`
2. Any user-visible behavior change must reflect in `README.md`.
3. Any coding-rule/process change for contributors/agents must reflect in `AGENTS.md`.
4. Do not leave docs stale after refactors.

## Privacy (Strict)

This repository is public. Nothing that identifies the owner's employer,
machine or private setup may enter the tree or the history.

1. Commit with the GitHub noreply address set in this repository's git config
   (`git config user.email`). Never commit with a work, university or personal
   address; check `git log -1 --format=%ae` before pushing.
2. No employer, university, course or client names anywhere: code, tests,
   docs, commit messages.
3. Test fixtures and examples use made-up data. Do not paste captured window
   titles, app lists, folder names or CLI output from a real machine without
   replacing the titles and names.
4. No real home-directory paths (`/Users/<name>/...`); use `~`, `/Users/me`
   or a path built at run time.
5. No signing identities, certificate hashes, team IDs, tokens or keys.
   `scripts/install.sh` finds the signing identity at run time; keep it so.
6. Do not commit logs, build output or review notes (`.build.log`, `review/`
   and the build folders are ignored; keep them ignored).
7. Personal configuration (AeroSpace config, private scripts, pinned apps,
   folder lists) lives outside the repository. Examples in `scripts/layouts/`
   must work for anyone.
8. If something of this kind was committed, say so and ask before rewriting
   history; a follow-up commit does not remove it from earlier commits.

## Forbidden Actions

1. Do not manually edit `OpenBoringBar.xcodeproj`.
   - If source-reference behavior needs change, edit `scripts/generate_xcodeproj.rb`.
2. Do not skip build validation.
3. Do not mix broad architecture rewrites with unrelated UI polish in one change.

## License Policy

1. This project follows the MIT License.
2. New code and documentation contributions must be MIT-compatible.
3. If adding third-party code/dependencies, verify license compatibility before merge.
