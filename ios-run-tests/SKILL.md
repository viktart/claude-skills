---
name: ios-run-tests
description: Runs iOS XCUITest tests on a simulator, extracts XCTAttachment screenshots from the xcresult bundle, displays them, and reports pass/fail with failure details. Use when user asks to run UI tests, run a test, take a screenshot, check the UI on simulator, or when UI tests need to be validated after a code change. Arguments: optional test scope — blank = all tests, ClassName, ClassName/method, or "build ClassName/method" to force a rebuild first.
---

# iOS — Run UI Tests

Runs iOS UI tests, captures screenshots, and reports results. Reads config from CLAUDE.md; falls back to live discovery if missing.

## 1. Load test configuration

Read the project CLAUDE.md and extract:
- **Scheme** — the Xcode scheme name
- **Simulator UDID** — the recorded test simulator
- **UI test target** — e.g. `MyAppUITests`
- **Bundle ID** — for launching the app after tests

If any of these are missing, run `/ios-update-test-docs` first, then resume.

## 2. Determine test scope from `$ARGUMENTS`

| Arguments | `-only-testing:` value |
|-----------|------------------------|
| _(blank)_ | `<Target>` |
| `ClassName` | `<Target>/ClassName` |
| `ClassName/method` | `<Target>/ClassName/method` |
| `build …` | Rebuild first, then run the rest as above |

## 3. Build (when needed)

Build when explicitly requested (`build` prefix in arguments), when no prior build exists in DerivedData, or when source files changed since the last build:

```bash
xcodebuild build-for-testing \
  -scheme <Scheme> \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -configuration Debug 2>&1 | grep -E "error:|Build succeeded|Build FAILED"
```

## 4. Run tests

```bash
xcodebuild test-without-building \
  -scheme <Scheme> \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:<scope> \
  2>&1 | grep -E "Test Case|error:|passed|failed|FAILED|SUCCEEDED"
```

Use `timeout: 300000` (5 min). For tests involving media processing use 600 000.

## 5. Extract screenshots

```bash
# newest by modification time — filenames don't sort reliably
RESULT="$(ls -td ~/Library/Developer/Xcode/DerivedData/<Scheme>-*/Logs/Test/*.xcresult | head -1)"

for f in "$RESULT/Data/"*; do
  [[ "$(file -b "$f")" == PNG* ]] && cp "$f" "/tmp/xctest_$(basename "$f").png"
done
```

Read every `/tmp/xctest_*.png` with the Read tool to display them inline.

## 6. Report results

State clearly:
- **Passed / Failed** with test name and duration
- For failures: the exact assertion line and message from the filtered output
- For each screenshot: one sentence describing what it shows and whether the UI looks correct
- If no screenshots were captured: remind that `XCTAttachment.lifetime` must be `.keepAlways`

If a test failed due to an element not being found (`XCTAssertTrue failed — element not found`), check whether the view uses `onTapGesture` instead of `Button` — see [reference.md](reference.md).

## 7. Live simulator screenshot (optional)

After tests, the simulator returns to the home screen. To capture the current app state:

```bash
xcrun simctl launch <UDID> <bundleId>
# wait ~8 seconds for app to load
xcrun simctl io <UDID> screenshot /tmp/live_app.png
```

Read `/tmp/live_app.png` and describe what the screen shows.
