---
name: ios-release-pipeline
description: Scaffolds and runs a Fastlane-based iOS release pipeline — bump semantic version, run tests, archive, upload to TestFlight/App Store Connect, then commit+tag+push the version bump. Use when user asks to set up CI/CD for an iOS app, release/ship a new build, cut a new version, bump the app version, or upload to App Store Connect/TestFlight. Arguments — optional: "scaffold" (install/refresh the pipeline files), "patch"/"minor"/"major" (bump type, default patch), "quick" (run the no-test lane locally instead of the full one).
---

# iOS — Release Pipeline

Sets up and runs a two-lane Fastlane release pipeline: a **full** lane (bump → test → archive → upload → commit/tag/push) for a developer's machine, and a cheaper **quick** lane (same minus the test step) for a manual GitHub Action. See [reference.md](reference.md) for the design + gotchas, [templates/](templates/) for the actual files to copy, and [certs-bootstrap.md](certs-bootstrap.md) for the `fastlane match` certs-repo setup.

## 1. Detect current state

```bash
find . -maxdepth 2 -iname "*.xcodeproj" -o -iname "project.yml" -maxdepth 2
test -f fastlane/Fastfile && echo "fastlane already set up"
xcodebuild -list 2>&1   # scheme + target names
grep -o 'MATCH_GIT_URL=.*' fastlane/.env 2>/dev/null
```

Determine: xcodegen project (`project.yml` present) vs plain `.xcodeproj`; scheme name; unit-test target name; app target's `PRODUCT_BUNDLE_IDENTIFIER`; whether `fastlane/Fastfile` already exists; whether a companion certs repo is configured (`MATCH_GIT_URL` in `fastlane/.env` or `fastlane/Matchfile`).

If `fastlane/Fastfile` exists and the user didn't pass `scaffold`, skip to **3. Run**. Otherwise go to **2. Scaffold**.

## 2. Scaffold

1. Confirm the discovered scheme, bundle ID, team ID, and unit-test target with the user before writing anything — these get baked into committed files.
2. **Never assume a simulator.** Run `xcrun simctl list devices available` and show the user the list — including whatever's currently booted, if anything. Even if exactly one simulator is booted, confirm it with the user rather than silently picking it; if none are booted or several are plausible, ask them to choose. The chosen name becomes `SIMULATOR_NAME` in the Fastfile.
3. If no companion certs repo is configured: propose `<repo-name>-certificates` as the name, and **ask the user to confirm** before running `gh repo create <name> --private`. This creates a new remote resource — never do it silently.
4. Copy each file from [templates/](templates/) to its destination (see the table in [reference.md](reference.md)), substituting the discovered values for the `<Placeholder>` tokens, including `<SimulatorName>`. Also copy all three `scripts/*.sh` into the repo at `fastlane/scripts/` and `chmod +x` them — the Fastfile invokes them from there (they must live in the repo, not the skill folder). Add `fastlane/.env` to `.gitignore` if it isn't already.
5. Add `gem "fastlane"` to the `Gemfile` if missing; run `bundle install` if a `Gemfile.lock` exists in the repo already.
6. Confirm with the user, then tell them to run **one command themselves, directly in their own terminal**: `bundle exec fastlane setup_certs`. See [certs-bootstrap.md](certs-bootstrap.md) — the lane now handles the whole chain itself: collects any missing secrets interactively (prompting only for the two credentials Apple/GitHub require creating through their web UI first), bootstraps the certs repo, pushes all 6 secrets to GitHub, and runs a permissions preflight. Don't run it via a tool call — it needs a real terminal for the interactive prompts.

## 3. Run

Parse `$ARGUMENTS` for a bump type (`patch` default, `minor`, `major`) and `quick`.

Before running, state the plan out loud: current version → new version, which lane (full/quick), and that this will push a commit+tag to the current branch and upload a build to TestFlight. **Get explicit go-ahead** — this is a hard-to-reverse, shared-state action (git push + external upload).

```bash
# full (local, runs tests)
bundle exec fastlane release bump_type:patch

# quick (no tests — normally triggered via the GitHub Action, but can run locally)
bundle exec fastlane release_quick bump_type:patch
```

If the certs repo hasn't been bootstrapped yet, both lanes fail fast with a message pointing at `setup_certs` (see reference.md) rather than a cryptic `match` error — if that happens, go back to **2.6** instead of retrying.

Stream the output. On failure, report the failing step verbatim (Fastlane names each action) — do not retry automatically. On success, report: old → new version, new build number, git tag, and the TestFlight processing state.

To trigger the CI variant instead of running locally: `gh workflow run ios-release.yml -f bump_type=patch`.
