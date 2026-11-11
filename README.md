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

OpenBoringBar runs as a background app: it has no Dock icon, no menu bar and
does not appear in Command-Tab. Quit it from the bar's right-click menu.
Only while the permission setup window is shown does it have a Dock icon.

- **Click a pill** to bring that app forward. If it is already in front,
  each click brings forward its next window on that display. Clicks never
  minimize.
- **Right-click a pill** to open a new window, switch to one of the app's
  windows on that display, pin or unpin the app, or quit it. If
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

### Start Menu

The Apple-logo button at the far left of the bar opens a menu:

- **Favorites**: apps you added yourself. Right-click an app's icon or pill
  on the bar and choose **Add to Start Menu** (**Remove from Start Menu**
  takes it out again). Favorites are listed in the order added and are not
  repeated under Frequently Used. They can also be removed in the menu:
  right-click one and choose **Remove from Favorites**.
- **Frequently Used**: the 10 apps you use most, plus every app pinned on
  that bar, most used first. The bar counts each time an app comes to the
  front; a use counts half as much after 30 days, so the list follows your
  habits. On first launch the list starts from what Spotlight recorded for
  apps used in the last 30 days. Right-click (or Control-click) an app in
  this list and choose **Remove from Frequently Used** to keep it out for
  good; **Restore Removed Apps** in that same right-click menu brings them
  all back.
- **All Applications**: every installed app by name (type to jump to a name).
- **Applications Folder**: browse `/Applications`, subfolders as submenus,
  with **Open “Applications” in Finder** at the top.
- **Folders**: folders you moved here from the bar (right-click a folder
  widget, **Move to Start Menu**), each as a submenu of its contents. The last
  items of a submenu move the folder back to the bar or remove it.
- **Workspace Layouts** (with AeroSpace): see below.

Click opens an app; Option-click reveals it in Finder.

### Workspace Layouts

A layout is a script that fills a workspace with a fixed set of windows. Every
executable file in `~/.config/openboringbar/layouts` is listed in the Start
menu; choosing one runs it with the name of the workspace shown on that bar as
its only argument. **Open Layouts Folder** opens that folder. The bar beeps if
the script exits with an error.

`scripts/layouts/terminal-finder-preview` is an example (`scripts/install.sh`
copies it): Alacritty on the left, Finder above Preview on the right. It opens
three new windows, so use it on an empty workspace. It can also be run from a
terminal: `terminal-finder-preview [workspace]`.

- Preview has no window without a document, so the script opens a blank
  placeholder page; set `PREVIEW_FILE` to open a file of yours instead.
  `FINDER_DIR` sets the folder of the Finder window (default: home).
- The first time, macOS asks whether OpenBoringBar may control Finder. If you
  decline, the script falls back to `open`, which goes to an existing Finder
  window of that folder if there is one.
- If you limit windows per workspace with an `on-window-detected` script, it
  must skip its work while `/tmp/aerospace-layout.hold` is fresh (the layout
  script touches that file while it runs).

### AeroSpace Workspaces

If [AeroSpace](https://github.com/nikitabobko/AeroSpace) is installed, the
bar's single row (44 pt) shows one group per workspace on that display that
has windows, in the order of the keyboard's number row (1–9, then 0), then any
other names. The workspace on screen holds its window pills; the others show
an icon per window. Empty workspaces are hidden, except the one on screen. The
focused workspace's name is in the accent color.

Which workspaces exist when empty is up to AeroSpace: list them under
`persistent-workspaces` in `~/.aerospace.toml`.

- **Click a workspace group** anywhere except on an icon (the name, the gaps,
  or just above or below the group) to go to it.
- **Click an icon** to focus that window.
- **Drag an icon** onto another group to move the window there. With Show
  Empty Workspaces off (the default), drop it on the dashed **+** to move it to the first
  empty workspace (1–9 first; `0` is never used). Moves are manual, so they may exceed any window limit you enforce in
  AeroSpace.
- **Show Workspaces** in the bar menu turns the groups off.
- **Show Empty Workspaces** (bar menu, off by default): turned on, empty
  workspaces are shown too, dimmed, and the dashed **+** goes away.
- **Pills Follow Workspace** (bar menu, on by default): the group of the
  workspace on screen shows one pill per window, titled with the window title;
  tiled windows left to right, then floating ones. Turned off, every group
  shows icons and the per-app pills follow the groups. The focused window's pill
  is highlighted, and clicking a pill focuses that window. Drag a pill onto a
  workspace group (or **+**) to move that window there. Use the workspace
  row to reach other workspaces. Turned off, pills are one per app as below.
  A minimized window keeps its pill on the workspace it was minimized from,
  dimmed and in italics; click it to restore the window there. Window menus
  list minimized windows too, marked "(minimized)".

If AeroSpace stops answering, the groups stay for 3 seconds, then go
away and the pills remain on their own.

AeroSpace does not report changes, so the bar re-reads it when an app is
activated, when windows open, close or move, after each click or drop, and
every 2 seconds. Set AeroSpace's `gaps.outer.bottom` to at least the bar height
(e.g. 52), or tiled windows will reach under the bar.

### Folders

Folder icons at the right of the bar (before the system stats). Click one for a menu of its contents: subfolders open as submenus,
click opens an item, Option-click reveals it in Finder. Right-click a folder
for Open in Finder, **Sort By** (Name, Date Added, Date Modified; folders stay
on top for folders imported that way), **Badge**, **Icon**, **Move to Start
Menu**, **Add Folder…** and **Remove**.

- **Badge** draws an image centered on the folder, with a white outline: any image
  file (**Choose Image…**, e.g. a Git logo PNG) or a built-in symbol (Download, Branch, Code, Chip, Book, Lecture, Document,
  Star, Photo, Music), drawn heavy and colored with a white outline. Each
  symbol has its own default color; **Badge Color** changes it. **No Badge** removes it.
- **Icon** replaces the folder icon with an image file; **Use Finder Icon**
  goes back. Custom icons set in Finder (Get Info, paste) show up without
  this.
- Image files are referenced by path; if one is moved or deleted, the widget
  falls back to the Finder icon or no badge.

On first launch the list is imported, read-only, from the
[Folder Peek](https://sindresorhus.com/folder-peek) app if it is installed
(its folders, sort order and folders-on-top setting); otherwise it starts with
`~/Downloads`, newest first. Toggle with **Show Folders** in the bar menu;
**Add Folder…** is there too.

### System Stats

Widgets at the right of the bar, in two compact rows: CPU and memory on top,
battery and startup-disk usage below. Values refresh every 2 seconds and turn orange at 80% and red at
90% (battery: at 20% and 10% while unplugged). Memory is "Memory Used" as
Activity Monitor computes it (app + wired + compressed). Click CPU or memory
for Activity Monitor, battery or disk for the matching System Settings page.
Macs without a battery show no battery widget. Toggle with **Show System
Stats** in the bar menu.

### Pinned Apps

Pinned apps are icons at the left of the bar that stay after the app quits.
The workspace groups and pills start to their right.

- **Running apps that are not pinned** follow the pins after a thin
  divider, like in the Dock, in the order they were launched, whether or not
  they have a window. They leave when the app quits. Click works as for a
  pin; right-click for New Window, the app's windows, **Pin to Bar** and
  **Quit**.
- **Pin**: right-click the app's icon or pill, choose **Pin to Bar**.
- **Open**: click the icon. A dot under it means the app is running.
- **With AeroSpace, a click stays on the workspace you are in.** If the app
  has a window on the workspace shown on that bar, the click focuses it (more
  clicks step through its windows there). If its windows are all on other
  workspaces, the click opens a new window here and does not jump to them.
- **New window**: Shift-click the icon, or choose **New Window** in the
  right-click menu of the icon or of a pill. This always opens a new window on
  the current workspace.
- New windows are opened by pressing the app's own menu item: "New Window",
  else "New … Window" (not private or incognito ones), else the item with the
  shortcut Command-N. A plain click only uses Command-N when the item is
  titled "New", "New Document" or "New File", so it never creates a note, an
  event or a message; Shift-click and **New Window** use whatever Command-N
  is. Apps with no such item, or where no window appears within about
  3 seconds, are brought forward instead, which goes to their existing
  window.
- If AeroSpace is not running, a click brings the app forward, like the Dock.
- **Reorder**: right-click the icon, choose **Move Left**, **Move Right**,
  **Move to Start**, or **Move to End**.
- **Unpin**: right-click the icon, choose **Unpin**.
- **Windows and Quit**: while the app runs, the icon's right-click menu also
  lists its windows from every workspace (minimized ones included) and offers
  **Quit**, so you can reach them from any workspace. Use this list to go to a
  window on another workspace.
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

## Install

```bash
./scripts/install.sh
```

Copies the Debug build to `~/Applications/OpenBoringBar.app`, signs it with
your Apple Development certificate (or `$SIGN_IDENTITY`; ad-hoc if there is
none) and relaunches the bar. A stable signature keeps the Accessibility and
Screen Recording permissions between builds.

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
