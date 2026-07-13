# iOS Run Tests — Reference

Universal simulator/XCUITest gotchas — the `simctl io` screenshot syntax, the home-screen reset after tests, `XCTAttachment.lifetime = .keepAlways`, the deprecated `xcresulttool`, screenshot extraction, and the accessibility-trait requirements for finding elements — live in the companion skill's doc: [../ios-update-test-docs/reference.md](../ios-update-test-docs/reference.md). Keep them there (single source); this file covers only diagnosis of a test run.

---

## Element not found failures

`app.buttons["myId"]` only matches elements with the **button accessibility trait** — a view using `onTapGesture` needs `.accessibilityAddTraits(.isButton)`, and identifiers beat localised label text. Full table and SwiftUI patterns: [../ios-update-test-docs/reference.md](../ios-update-test-docs/reference.md) § XCUITest accessibility requirements.

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
