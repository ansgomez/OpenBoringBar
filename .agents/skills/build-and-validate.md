# Skill: Build And Validate

Use this workflow after any code change.

## Quick Path

```bash
./scripts/bootstrap.sh
```

This script will:

1. Run `pod install`.
2. Build `OpenBoringBar` in Debug for macOS via `xcodebuild`.
3. Run the `OpenBoringBarTests` unit tests via `xcodebuild test` (hostless;
   does not launch the app).

## Manual Commands

```bash
pod install
xcodebuild \
  -project OpenBoringBar.xcodeproj \
  -scheme OpenBoringBar \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build
xcodebuild \
  -project OpenBoringBar.xcodeproj \
  -scheme OpenBoringBar \
  -configuration Debug \
  -sdk macosx \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  test
```

## Expected Outputs

- No pod install failure.
- No compile/link failure.
- App target `OpenBoringBar` builds successfully.
- `** TEST SUCCEEDED **` with 0 failures.

## If Build Fails

1. Confirm changed files match layer boundaries.
2. Check for missing imports or access control issues.
3. Verify new files are under source globs used by `scripts/generate_xcodeproj.rb`.
   App sources used by tests must also be in `APP_SOURCES_UNDER_TEST`.
4. Re-run `./scripts/bootstrap.sh` after fixing.
