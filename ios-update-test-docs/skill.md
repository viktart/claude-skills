---
name: ios-update-test-docs
description: Discovers an iOS Xcode project's test configuration and writes it into the project's CLAUDE.md (Build & Test and UI Testing sections). Records the chosen simulator, real bundle ID, scheme, test targets, test classes, and ready-to-paste commands. Use when setting up a new iOS project, after a simulator or target change, or when CLAUDE.md test info is missing or stale.
---

# iOS — Update Test Docs

Syncs the current iOS project's test setup into CLAUDE.md so future sessions skip all re-discovery.

## Workflow

### 1. Discover project structure

```bash
find . -name "*.xcodeproj" -maxdepth 3 | head -3
xcodebuild -list 2>&1
find . -path "*UITests*" -name "*.swift" ! -path "*/DerivedData/*"
```

From the UITest Swift files, grep for `class.*XCTestCase` and `func test` to list every test class and method.

### 2. Select simulator

```bash
xcrun simctl list devices | grep "Booted"
```

- **None booted:** show all available simulators and ask which to use (or offer to boot one).
- **One booted:** confirm with user before recording it.
- **Multiple booted:** list each with name, iOS version, and UDID — **ask the user to choose**.

### 3. Discover app bundle ID

```bash
xcrun simctl listapps <UDID> 2>/dev/null
```

Find the entry where `CFBundleDisplayName` or `CFBundleName` matches the project name. Record the exact `CFBundleIdentifier`. **Never assume** — it often differs from the scheme name.

If the app isn't installed yet, look in `*.xcodeproj/project.pbxproj` for `PRODUCT_BUNDLE_IDENTIFIER`.

### 4. Update CLAUDE.md

Read the current CLAUDE.md. Replace or create exactly these two sections; leave all others untouched.

**## Build & Test** — write:
- Simulator: display name, iOS version, UDID — note that it has test data pre-loaded
- `xcodebuild build-for-testing` command with exact scheme + destination flags
- `xcodebuild test-without-building` with `-only-testing:` shown at all three levels:
  `Target`, `Target/Class`, `Target/Class/Method`
- Full list of UI test targets → classes → methods found in step 1

**## UI Testing** — write:
- App launch: `xcrun simctl launch <UDID> <bundleId>`
- Live screenshot: `xcrun simctl io <UDID> screenshot /tmp/screen.png`
- xcresult location: `~/Library/Developer/Xcode/DerivedData/<Scheme>-*/Logs/Test/*.xcresult`
- Screenshot extraction snippet (copy from [reference.md](reference.md) § Extracting screenshots)
- Link to [reference.md](reference.md) for gotchas and accessibility requirements

See [reference.md](reference.md) for universal gotchas, screenshot extraction, and XCUITest requirements.
