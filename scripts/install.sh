#!/usr/bin/env bash
# Installs the Debug build as ~/Applications/OpenBoringBar.app and relaunches
# the bar. Run ./scripts/bootstrap.sh (or xcodebuild) first.
#
# The copy is signed with a stable identity, so macOS keeps the Accessibility
# and Screen Recording permissions between builds (the ad-hoc signature of a
# plain build changes every time). Identity: $SIGN_IDENTITY, else the first
# "Apple Development" certificate in the keychain, else ad-hoc.
#
# Also copies the example workspace layouts to ~/.config/openboringbar/layouts
# (existing files there are not overwritten).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILT_APP="$ROOT_DIR/.build/DerivedData/Build/Products/Debug/OpenBoringBar.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/OpenBoringBar.app"
LAYOUTS_DIR="$HOME/.config/openboringbar/layouts"

[ -d "$BUILT_APP" ] || { echo "No build at $BUILT_APP; run ./scripts/bootstrap.sh first." >&2; exit 1; }

identity="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ { print $2; exit }')}"
identity="${identity:--}"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
staged="$stage/OpenBoringBar.app"
ditto "$BUILT_APP" "$staged"

echo "==> signing with ${identity}"
find "$staged/Contents/MacOS" -name '*.dylib' -exec \
    codesign --force --sign "$identity" --timestamp=none {} \; 2>/dev/null
codesign --force --sign "$identity" --timestamp=none --options runtime \
    --entitlements "$ROOT_DIR/scripts/OpenBoringBar.entitlements" "$staged" 2>/dev/null
codesign --verify --deep --strict "$staged"

echo "==> replacing $INSTALLED_APP"
osascript -e 'tell application id "com.openboringbar.app" to quit' >/dev/null 2>&1 || true
for _ in $(seq 1 10); do
    pgrep -x OpenBoringBar >/dev/null || break
    sleep 0.5
done
if pgrep -x OpenBoringBar >/dev/null; then
    echo "OpenBoringBar is still running; quit it and run this again." >&2
    exit 1
fi
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
ditto "$staged" "$INSTALLED_APP"

mkdir -p "$LAYOUTS_DIR"
for file in "$ROOT_DIR"/scripts/layouts/*; do
    [ -e "$LAYOUTS_DIR/$(basename "$file")" ] || cp -p "$file" "$LAYOUTS_DIR/"
done

open "$INSTALLED_APP"
echo "==> launched"
