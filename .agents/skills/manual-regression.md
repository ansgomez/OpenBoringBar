# Skill: Manual Regression

Run these scenarios after successful build.

## 1) Permission Setup Flow

- Launch app with missing permissions.
- Verify onboarding/setup UI appears.
- Grant required permissions and confirm app transitions to running state.

## 2) Multi-Display Bar Create/Remove

- Attach two or more displays.
- Confirm each display has a bottom bar.
- Disconnect/reconnect displays and confirm bars are removed/recreated correctly.

## 3) App Switch From Capsule

- Open several apps.
- Click capsule items from the bar.
- Verify frontmost app switches correctly and consistently.

## 4) Start Menu

- Click the Start button at the far left.
- Launch an app from Frequently Used and one from All Applications; verify
  it opens with focus.
- Right-click an app icon on the bar, choose Add to Start Menu, and verify it
  appears under Favorites; remove it again.
- Open a folder under Folders and under Applications Folder.

## 5) Bottom Guard Behavior

- Bring frontmost windows to the lower screen edge.
- Verify guard behavior prevents unintended overlap/conflict with bar.

## 6) Pinned And Running Apps

- Pin an app, quit it, and verify its icon joins the stack of idle pins.
- Rest the pointer on the stack; verify it unfolds and folds when the pointer
  leaves the pin strip.
- Launch an app that is not pinned; verify its icon appears after the pins
  and leaves when the app quits.

## 7) Workspace Groups (with AeroSpace)

- Click a workspace group, then an icon in another group; verify the switch
  and the focus.
- With three windows on a workspace, verify only the focused window has a
  full pill, and that resting on a folded pill unfolds them.
- Minimize a window; verify its icon appears in the "–" group at once. Click
  it and verify the window returns on the current workspace.
- Drag a pill onto another workspace group and onto the "–" group.

## 8) Documentation Images

- After a visual change, run `./scripts/render-screenshots.sh` and look at
  the images in `docs/screenshots`.

## Regression Notes Template

- Build command and result.
- Devices/displays used.
- Scenario-by-scenario pass/fail.
- Any flaky or uncertain behavior with reproduction steps.
