#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.home"
export HOME="$ROOT_DIR/.home"

echo "==> 1/3 pod install (自动生成 Xcode 工程 + workspace)"
pod install

echo "==> 2/3 xcodebuild (Debug/macOS)"
xcodebuild \
  -project OpenBoringBar.xcodeproj \
  -scheme OpenBoringBar \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build

echo "==> 3/3 xcodebuild test (unit tests; does not launch the app)"
xcodebuild \
  -project OpenBoringBar.xcodeproj \
  -scheme OpenBoringBar \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  test
