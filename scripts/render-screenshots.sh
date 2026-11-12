#!/usr/bin/env bash
# Renders the documentation images in docs/screenshots from made-up data.
# The app draws its own bar offscreen; nothing is captured from the screen.
# Build first (./scripts/bootstrap.sh).
set -euo pipefail

cd "$(dirname "$0")/.."
app=".build/DerivedData/Build/Products/Debug/OpenBoringBar.app/Contents/MacOS/OpenBoringBar"
if [[ ! -x "$app" ]]; then
    echo "Build not found: run ./scripts/bootstrap.sh first" >&2
    exit 1
fi
out="${1:-docs/screenshots}"
"$app" --render-screenshots "$out"
echo "==> rendered to $out"
ls -1 "$out"
