# iOS Test Docs — Reference

Universal gotchas, command details, and XCUITest requirements for iOS simulator testing.

---

## Gotchas

### Commands

| Wrong | Right |
|-------|-------|
| `xcrun simctl screenshot <UDID> out.png` | `xcrun simctl io <UDID> screenshot out.png` |
| `xcodebuild test` (rebuilds every time) | `build-for-testing` once, then `test-without-building` |
| `xcresulttool export` (deprecated) | Read `Data/` dir directly — see below |

### Bundle ID
Always discover from `xcrun simctl listapps <UDID>` — never infer from scheme name.
The actual `CFBundleIdentifier` is the value you must pass to `simctl launch`.

### Simulator state after test run
After `xcodebuild test-without-building` finishes the simulator returns to the **home screen**.
To take a live screenshot of the app, launch it again first:
```bash
xcrun simctl launch <UDID> <bundleId>
sleep 8   # wait for app load
xcrun simctl io <UDID> screenshot /tmp/live.png
```

---

## Extracting screenshots from xcresult

Test attachments created with `XCTAttachment` end up inside the `.xcresult` bundle's `Data/` directory as files with no extension. Use `file -b` to identify PNGs:

```bash
# newest by modification time — filenames don't sort reliably
RESULT="$(ls -td ~/Library/Developer/Xcode/DerivedData/<Scheme>-*/Logs/Test/*.xcresult | head -1)"

for f in "$RESULT/Data/"*; do
  [[ "$(file -b "$f")" == PNG* ]] && cp "$f" "/tmp/xctest_$(basename "$f").png"
done
```

Then `Read` each `/tmp/xctest_*.png` to inspect them. Keep the `xctest_` prefix — it's the shared convention with the `ios-run-tests` skill, which reads (and other tooling verifies) `/tmp/xctest_*.png`.

**Required in test code** — attachments are deleted on success by default:
```swift
let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
a.name = "meaningful_name"
a.lifetime = .keepAlways   // ← without this, passes delete the file
add(a)
```

---

## XCUITest accessibility requirements

### Finding elements
`app.buttons["myId"]` only matches views that have the **button accessibility trait**.

| View type | How to make it findable as a button |
|-----------|-------------------------------------|
| `Button { } label: { }` | Works automatically |
| View + `onTapGesture` | Add `.accessibilityAddTraits(.isButton)` |
| View + tap + drag | Use `Button` + `.simultaneousGesture(DragGesture(...))` |

Always set `.accessibilityIdentifier("id")` — accessibility labels are localised and fragile for tests.

### Combining tap and drag on the same view
```swift
Button { /* tap action */ } label: { handleView }
    .buttonStyle(.plain)
    .simultaneousGesture(
        DragGesture(minimumDistance: 8)
            .onChanged { dragTranslation = $0.translation.height }
            .onEnded { endDrag($0) }
    )
    .accessibilityIdentifier("handleButton")
```
`simultaneousGesture` lets both the button tap and the drag be recognised independently without either blocking the other.

### Photo library permission in tests
Handle before interacting with the grid:
```swift
let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
for label in ["Allow Full Access", "Allow Access to All Photos", "OK"] {
    let btn = springboard.buttons[label]
    if btn.waitForExistence(timeout: 4) { btn.tap(); break }
}
```

---

## Build & test command patterns

```bash
# Build once
xcodebuild build-for-testing \
  -scheme <Scheme> \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -configuration Debug 2>&1 | grep -E "error:|succeeded|FAILED"

# Run all tests in a target
xcodebuild test-without-building \
  -scheme <Scheme> \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:<Target>

# Run one class
  -only-testing:<Target>/<Class>

# Run one method
  -only-testing:<Target>/<Class>/<Method>

# Filter output
2>&1 | grep -E "Test Case|error:|passed|failed|SUCCEEDED|FAILED"
```

Set command timeout to at least 300 000 ms (5 min) for tests that include real media processing.
