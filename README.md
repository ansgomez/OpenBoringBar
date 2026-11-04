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
  display, pin or unpin the app, or quit it.
- **Right-click empty bar space** for Quit OpenBoringBar, Auto-collapse, and
  Show Pins On.

### Pinned Apps

Pinned apps are icons at the left of the bar that stay after the app quits.

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
