# iOS Run Tests — Reference

## Critical gotchas

### Screenshot command
```bash
# WRONG — this subcommand does not exist
xcrun simctl screenshot <UDID> out.png

# RIGHT
xcrun simctl io <UDID> screenshot out.png
```

### Simulator returns to home screen after tests
Always `xcrun simctl launch <UDID> <bundleId>` before taking a live screenshot.
Wait ~8 seconds after launch before capturing.

### Test screenshots are deleted on success by default
Tests must opt in to keeping attachments:
```swift
let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
a.name = "step_name"
a.lifetime = .keepAlways   // required — default deletes on pass
add(a)
```
If no PNGs appear in the xcresult, this is almost always the cause.

### `xcresulttool` API is deprecated
Do not use `xcresulttool export` or `xcresulttool get --format json` — both have breaking changes across Xcode versions. Read the `Data/` directory directly and use `file -b` to detect PNGs.

---

## Element not found failures

`app.buttons["myId"]` only matches elements with the **button accessibility trait**.

| Situation | Fix |
|-----------|-----|
| Using `onTapGesture` on a plain view | Add `.accessibilityAddTraits(.isButton)` |
| Need tap + drag on the same view | Use `Button` + `.simultaneousGesture(DragGesture(...))` |
| Trait is correct but element missing | Verify `.accessibilityIdentifier("myId")` is set — don't rely on label text (it's localised) |

---

## Diagnosing common failures

| Symptom | Likely cause |
|---------|-------------|
| `XCTAssertTrue failed — element not found` | Wrong accessibility type, missing identifier, or element not yet visible (increase `waitForExistence` timeout) |
| `Test Case … failed (0 seconds)` | App crashed on launch — check device logs |
| No screenshots in xcresult | `lifetime` not set to `.keepAlways` |
| `BUILD FAILED` with signing errors | Run in Simulator not device — confirm destination UDID is a simulator |
| Test hangs / timeout | Long media processing; increase command timeout to 600 000 ms |
| `simctl launch` fails with code 4 | Wrong bundle ID — re-run `xcrun simctl listapps <UDID>` to get the real one |

---

## Filtering xcodebuild output

```bash
# Useful during build
2>&1 | grep -E "error:|warning:.*MyFile|succeeded|FAILED"

# Useful during test run
2>&1 | grep -E "Test Case|error:|passed|failed|SUCCEEDED|FAILED"

# Show only failures with context
2>&1 | grep -E -A3 "failed|error:"
```

---

## Finding the xcresult path

The DerivedData slug changes per machine. Use a glob:
```bash
find ~/Library/Developer/Xcode/DerivedData/<Scheme>-*/Logs/Test \
  -name "*.xcresult" | sort | tail -1
```

The most recently modified `.xcresult` is always the last run.
