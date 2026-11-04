# OpenBoringBar

<p align="center">
  <img src="docs/assets/app-icon.png" alt="OpenBoringBar App Icon" width="160" />
</p>

OpenBoringBar is an open-source alternative to [boringbar.app](https://boringbar.app), focused on delivering a practical macOS bottom taskbar experience for multi-display setups.

## Screenshots

### Normal Bar

![Normal Bar](docs/screenshots/normal-looks-like.png)

### Multi-Window Preview

![Multi-Window Preview](docs/screenshots/multi-preview-window.png)

### App Launcher Search

![App Launcher Search](docs/screenshots/file-search.png)

## Using The Bar

- **Click a pill** to bring that app forward. If it is already in front,
  each click brings forward its next window on that display. Clicks never
  minimize.
- **Right-click a pill** to switch to one of the app's windows on that
  display, pin or unpin the app, or quit it. If
  [AeroSpace](https://github.com/nikitabobko/AeroSpace) is installed (found at
  `/opt/homebrew/bin/aerospace` or `/usr/local/bin/aerospace`), each window
  shows its workspace name; windows on the current workspace come first, with
  the name highlighted.
- **Right-click empty bar space** for Quit OpenBoringBar, Auto-collapse,
  Hide Off-Screen Windows, and Show Pins On.
- **Hide Off-Screen Windows** (on by default) ignores windows that are less
  than 10% visible. Tiling window managers such as AeroSpace hide other
  workspaces' windows by moving them almost off-screen; with this on, apps
  whose windows are all on other workspaces get no pill. Clicking a pill still
  cycles through all of that app's windows, including ones on other
  workspaces, and the pill's right-click menu lists them all. The "keep windows
  above the bar" resize also leaves windows alone when less than half of them
  is on screen.

### AeroSpace Workspaces

If [AeroSpace](https://github.com/nikitabobko/AeroSpace) is installed, the bar
gets a second row above the pills, 30 pt high (the bar becomes 75 pt). It shows
one group per workspace on that display that has windows, plus the visible
one, with an icon per window. The focused workspace's name is in the accent
color.

- **Click a workspace name** to go to it.
- **Click an icon** to focus that window.
- **Drag an icon** onto another group to move the window there, or onto the
  dashed **+** to move it to the first empty workspace (1–9 first; `0` is never
  used). Moves are manual, so they may exceed any window limit you enforce in
  AeroSpace.
- **Show Workspaces** in the bar menu turns the row off (the bar goes back to
  44 pt).
- **Pills Follow Workspace** (bar menu, on by default): the pill row shows one
  pill per window of the workspace on screen, titled with the window title;
  tiled windows left to right, then floating ones. The focused window's pill
  is highlighted, and clicking a pill focuses that window. Drag a pill onto a
  workspace group (or **+**) to move that window there. Use the workspace
  row to reach other workspaces. Turned off, pills are one per app as below.

AeroSpace does not report changes, so the bar re-reads it when an app is
activated, when windows open, close or move, after each click or drop, and
every 2 seconds. Set AeroSpace's `gaps.outer.bottom` to at least the bar height
(e.g. 84 with the row, 52 without), or tiled windows will reach under the bar.

### Pinned Apps

Pinned apps are icons at the left of the bar that stay after the app quits.
They span the full bar height: with the AeroSpace workspace row shown they
sit in two rows (top row first, left to right), and the workspace row and the
pills start at the same left edge to their right.

- **Pin**: open the app, right-click its pill, choose **Pin to Bar**.
- **Open**: click the icon. A dot under it means the app is running.
- **Reorder**: right-click the icon, choose **Move Left**, **Move Right**,
  **Move to Start**, or **Move to End**.
- **Unpin**: right-click the icon, choose **Unpin**.
- **Show Pins On** (right-click empty bar space):
  - **All Displays** (default): every bar shows the same pins.
  - **Main Display Only**: only the bar on the display with the menu bar shows
    pins.
  - **Each Display Separately**: each display keeps its own list, which starts
    as a copy of the shared list the first time you edit it.

Pins follow an app when it moves, because they are matched by bundle
identifier. A pin whose app cannot be found (for example, on an unplugged
drive) is hidden, not deleted, and comes back when the app is found again.

## Requirements

- macOS 14+
- Xcode 26+
- CocoaPods (`pod` available in shell)

## Bootstrap And Build

```bash
./scripts/bootstrap.sh
```

This script runs:

1. `pod install` to regenerate project/workspace metadata.
2. `xcodebuild` for a Debug build of scheme `OpenBoringBar`.
3. `xcodebuild test` for the `OpenBoringBarTests` unit tests. The test bundle
   compiles the pin logic directly and does not launch the app.

## Manual Commands

```bash
pod install
xcodebuild -project OpenBoringBar.xcodeproj -scheme OpenBoringBar -configuration Debug -sdk macosx -destination 'platform=macOS' build
xcodebuild -project OpenBoringBar.xcodeproj -scheme OpenBoringBar -configuration Debug -sdk macosx -destination 'platform=macOS' test
```

## Agent Workspace

This repository includes an AI contributor knowledge base under `.agents/`.

- Entry point: `AGENTS.md`
- Knowledge base index: `.agents/AGENTS.md`
- Rules: `.agents/rules/`
- Workflows: `.agents/skills/`
- Validation checklist: `.agents/checklists/change-done-checklist.md`

Recommended reading order for contributors and coding agents:

1. `AGENTS.md`
2. `.agents/rules/`
3. `.agents/skills/feature-delivery.md`
4. `.agents/skills/build-and-validate.md`
5. `.agents/skills/manual-regression.md`

## License

OpenBoringBar is released under the MIT License. See [LICENSE](./LICENSE) for details.
