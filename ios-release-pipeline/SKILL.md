---
name: ios-release-pipeline
description: Scaffolds and runs a Fastlane-based iOS release pipeline — bump semantic version, run tests, archive, upload to TestFlight/App Store Connect, then commit+tag+push the version bump. Use when user asks to set up CI/CD for an iOS app, release/ship a new build, cut a new version, bump the app version, or upload to App Store Connect/TestFlight. Arguments — optional: "scaffold" (install/refresh the pipeline files), "patch"/"minor"/"major" (bump type, default patch), "quick" (run the no-test lane locally instead of the full one).
---

# iOS — Release Pipeline

Sets up and runs a two-lane Fastlane release pipeline: a **full** lane (bump → test → archive → upload → commit/tag/push) for a developer's machine, and a cheaper **quick** lane (same minus the test step) for a manual GitHub Action. See [reference.md](reference.md) for the design + gotchas, [templates/](templates/) for the actual files to copy, and [secrets-bootstrap.md](secrets-bootstrap.md) for the App Store Connect key setup. Signing uses Apple's cloud-managed certificates (`xcodebuild` cloud signing) — there is no certs repo, no `fastlane match`, and no local certificate anywhere in the pipeline.

## 1. Detect current state

```bash
find . -maxdepth 2 \( -iname "*.xcodeproj" -o -iname "project.yml" \)
test -f fastlane/Fastfile && echo "fastlane already set up"
xcodebuild -list 2>&1   # scheme + target names
grep -c '^ASC_KEY_ID=.' fastlane/.env 2>/dev/null   # 1 = secrets already collected
```

Determine: xcodegen project (`project.yml` present) vs plain `.xcodeproj`; scheme name; app target name and `.xcodeproj` file name (often but not always the same as the scheme — check, don't assume); unit-test target name; app target's `PRODUCT_BUNDLE_IDENTIFIER`; whether `fastlane/Fastfile` already exists; whether the secrets are already collected (`ASC_KEY_ID` populated in `fastlane/.env`).

If `fastlane/Fastfile` exists and the user didn't pass `scaffold`, skip to **3. Run**. Otherwise go to **2. Scaffold**.

## 2. Scaffold

1. Confirm the discovered scheme, app target, `.xcodeproj` name, bundle ID, team ID, and unit-test target with the user before writing anything — these get baked into committed files.
2. **Check the app target is set up for automatic signing** — cloud signing requires it: `CODE_SIGN_STYLE` must be `Automatic` (Xcode's default) and `DEVELOPMENT_TEAM` must be set in the target's build settings (or under `settings:` in `project.yml` for xcodegen projects). If either is off, tell the user what to change before continuing.
3. **Never assume a simulator.** Run `xcrun simctl list devices available` and show the user the list — including whatever's currently booted, if anything. Even if exactly one simulator is booted, confirm it with the user rather than silently picking it; if none are booted or several are plausible, ask them to choose. The chosen name becomes `SIMULATOR_NAME` in the Fastfile.
4. Copy each file from [templates/](templates/) to its destination (see the table in [reference.md](reference.md)), substituting the discovered values for the `<Placeholder>` tokens, including `<SimulatorName>`. Also copy all three `scripts/*.sh` into the repo at `fastlane/scripts/` and `chmod +x` them — the Fastfile invokes them from there (they must live in the repo, not the skill folder). Add `fastlane/.env` to `.gitignore` if it isn't already.
5. Add `gem "fastlane"` to the `Gemfile` if missing; run `bundle install` if a `Gemfile.lock` exists in the repo already.
6. Confirm with the user, then tell them to run **one command themselves, directly in their own terminal**: `bundle exec fastlane setup_secrets`. See [secrets-bootstrap.md](secrets-bootstrap.md) — the lane handles the whole chain itself: collects the App Store Connect API key interactively (the one credential Apple requires creating through their web UI first), pushes the 3 secrets to GitHub, and runs a permissions preflight. Don't run it via a tool call — it needs a real terminal for the interactive prompts.

## 3. Run

Parse `$ARGUMENTS` for a bump type (`patch` default, `minor`, `major`) and `quick`.

Before running, state the plan out loud: current version → new version, which lane (full/quick), and that this will push a commit+tag to the current branch and upload a build to TestFlight. **Get explicit go-ahead** — this is a hard-to-reverse, shared-state action (git push + external upload).

```bash
# full (local, runs tests)
bundle exec fastlane release bump_type:patch

# quick (no tests — normally triggered via the GitHub Action, but can run locally)
bundle exec fastlane release_quick bump_type:patch
```

If the secrets haven't been collected yet, both lanes fail fast with a message pointing at `setup_secrets` (see reference.md) rather than a cryptic signing error — if that happens, go back to **2.6** instead of retrying.

Stream the output. On failure, report the failing step verbatim (Fastlane names each action) — do not retry automatically. On success, report: old → new version, new build number, git tag, and the TestFlight processing state.

To trigger the CI variant instead of running locally: `gh workflow run ios-release.yml -f bump_type=patch`.
