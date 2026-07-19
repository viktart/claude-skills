# iOS Release Pipeline — Reference

## Design

Three public Fastlane lanes share several private helpers — see [templates/Fastfile](templates/Fastfile) for the full implementation:

- `bump_app_version(bump_type:)` — bumps `MARKETING_VERSION`, returns the new version string.
- `run_unit_tests` — builds for testing + runs the unit test target only, against `SIMULATOR_NAME` (chosen interactively at scaffold time — UI tests are out of scope here, use the `ios-run-tests` skill for those).
- `ensure_secrets_ready` — checks the 3 App Store Connect secrets are present in ENV (loaded from `.env` locally, or CI env); `UI.user_error!`s toward `setup_secrets` if any are missing, instead of letting the build fail with a cryptic signing error. Secrets-in-ENV is the reliable "setup_secrets has already run" signal.
- `build_and_upload` — `ensure_secrets_ready` → `increment_build_number` from the latest TestFlight build → `build_app` (archive + export, cloud-signed) → `upload_to_testflight`.
- `commit_tag_and_push(version:)` — commits the version-bump files (only those git tracks — xcodegen projects often gitignore the `.xcodeproj`), tags `v<version>`, pushes branch + tag.
- `asc_api_key` / `asc_key_file` — build the fastlane API-key object, and materialize the `.p8` (from base64 `ASC_KEY_CONTENT`) at an absolute path outside the repo for `xcodebuild`'s `-authenticationKeyPath`.
- `ensure_secrets_collected` / `push_secrets_to_github` / `check_workflow_permissions` — only called from `setup_secrets`, see [secrets-bootstrap.md](secrets-bootstrap.md).

`release` (full) = bump → **run_unit_tests** → build_and_upload → commit_tag_and_push.
`release_quick` (partial, CI) = bump → build_and_upload → commit_tag_and_push — **no test step**, kept cheap for on-demand GitHub Actions runs.
`setup_secrets` = the entire secrets bootstrap chain, see [secrets-bootstrap.md](secrets-bootstrap.md).

The version bump happens first but the git push happens **last, only if everything else succeeded** — a failed test or upload never leaves an orphaned version-bump commit in history.

## Signing: cloud-managed certificates

There is deliberately **no `fastlane match`, no certs repo, and no local certificate** in this pipeline. `build_app` passes `-allowProvisioningUpdates -authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID` to `xcodebuild` (via `xcargs` **and** `export_xcargs` — the export step re-signs and needs them too). Xcode authenticates to Apple with the same App Store Connect API key used for the upload, and Apple signs with a **cloud-managed distribution certificate** — created automatically on first use, held and renewed on Apple's servers, never present on the build machine.

Consequences worth knowing:

- The project must use **automatic signing** (`CODE_SIGN_STYLE = Automatic`) with `DEVELOPMENT_TEAM` set — checked at scaffold time (SKILL.md step 2.2).
- The API key needs **App Manager** access or higher for cloud signing to be allowed to create/use the cloud certificate.
- The 3 ASC secrets are the pipeline's *only* credential — one thing to rotate, one thing to leak-audit.
- The `.p8` can never be re-downloaded from Apple, and GitHub secrets are write-only — the user's local `fastlane/.env` (or the original `.p8`) is the only recoverable copy; `collect-secrets.sh` tells them to back it up.

## Templates and where they go

| Template | Destination in target repo | Placeholders to substitute |
|---|---|---|
| [templates/Fastfile](templates/Fastfile) | `fastlane/Fastfile` | `<Scheme>`, `<AppTarget>`, `<XcodeprojName>`, `<UnitTestTarget>`, `<true_or_false>` (`USES_XCODEGEN`), `<SimulatorName>` |
| [templates/Appfile](templates/Appfile) | `fastlane/Appfile` | `<AppIdentifier>`, `<TeamID>` |
| [templates/env.example](templates/env.example) | `fastlane/.env.example` | none — copy verbatim, never fill in real values |
| [templates/ios-release.yml](templates/ios-release.yml) | `.github/workflows/ios-release.yml` | none — copy verbatim |

`<SimulatorName>` is never guessed — see SKILL.md scaffold step 2.3. Never write a real `fastlane/.env` for the user — only the `.example` file with empty values; real secrets are populated by `setup_secrets` itself (see [secrets-bootstrap.md](secrets-bootstrap.md)).

## Scripts

The three `scripts/*.sh` are **copied into the target repo at `fastlane/scripts/`** during scaffold step 4 (and `chmod +x`) — the Fastfile resolves them relative to its own dir (`File.expand_path("scripts/…", __dir__)`), so they must live in the repo, not the skill folder. All three are invoked *by the `setup_secrets` lane itself* (see [secrets-bootstrap.md](secrets-bootstrap.md)) — nobody runs them individually.

| Script | Invoked via | Purpose |
|---|---|---|
| [scripts/collect-secrets.sh](scripts/collect-secrets.sh) | `system` (real TTY passthrough) from `ensure_secrets_collected` | Prompts for the App Store Connect API key (the one credential that requires a manual Apple web-UI step), writes the 3 secrets to `fastlane/.env`. |
| [scripts/set-github-secrets.sh](scripts/set-github-secrets.sh) | `system` from `push_secrets_to_github` | Reads `fastlane/.env`, pushes the 3 secrets to the repo via `gh secret set`. |
| [scripts/check-workflow-permissions.sh](scripts/check-workflow-permissions.sh) | `system` from `check_workflow_permissions` | Read-only preflight warning about `GITHUB_TOKEN` permissions. |

`system`, not the `sh` action, is used everywhere these are called: `sh` pipes output for fastlane's own logging, which can break `collect-secrets.sh`'s interactive `read` prompts. `system` inherits the parent process's TTY untouched.

## `permissions: contents: write`

Plus the default `GITHUB_TOKEN` (already checked out with `persist-credentials: true` by default) is what lets `push_to_git_remote` push the version-bump commit and tag back — no extra PAT needed. With cloud signing there is no other GitHub credential in the pipeline at all.

## Gotchas

| Symptom | Cause / fix |
|---|---|
| `xcodegen generate` overwrites a manual build-number bump | Always bump `MARKETING_VERSION` (and run `xcodegen generate`) **before** `increment_build_number` — never after. The lane order above already does this. |
| `latest_testflight_build_number` errors on a brand-new app | No build has ever been uploaded. `rescue 0` in `build_and_upload`, or hardcode `build_number: 1` for the first manual run. |
| `git_commit` fails in CI with "please tell me who you are" | Set `git config user.name`/`user.email` before committing when `is_ci` — the template does this. |
| Push from the GitHub Action is rejected | Workflow needs `permissions: contents: write`; `actions/checkout` must use `fetch-depth: 0` so tags/history are available to push against. |
| Archive fails with "requires a provisioning profile" / "no profiles found" | Project is on manual signing — cloud signing needs `CODE_SIGN_STYLE = Automatic` on the app target (SKILL.md step 2.2). |
| "Signing requires a development team" | `DEVELOPMENT_TEAM` not set in the target's build settings (or `project.yml` `settings:` for xcodegen). |
| `xcodebuild` prompts for an Apple ID, or export fails after a successful archive | The three `-authentication…` flags must be on **both** steps — `xcargs` (archive) *and* `export_xcargs` (export). The template passes the same string to both. |
| "Cloud signing permission error" / cert not created on first build | The ASC API key's access level is too low — cloud signing needs **App Manager** or higher. Re-issue the key with the right role. |
| Version bump committed but build/upload had already failed | Shouldn't happen — `commit_tag_and_push` is the last step in both lanes, called only if every prior step succeeded (Fastlane aborts the lane on the first failing action). |
| Plain `.xcodeproj` project (no `project.yml`) | Set `USES_XCODEGEN = false` in the Fastfile; `bump_app_version` then uses `increment_version_number` directly on the `.xcodeproj`, no regeneration step needed. |
| `increment_version_number`/`increment_build_number` fails with "Apple Generic Versioning is not enabled" | The project needs `VERSIONING_SYSTEM = apple-generic` (and a `CURRENT_PROJECT_VERSION`) in its build settings — set it in Xcode, or under `settings:` in `project.yml` for xcodegen projects. |
| Version-bump commit fails: pbxproj not tracked by git | Expected for xcodegen projects that gitignore the `.xcodeproj` — `commit_tag_and_push` commits only the files git tracks (usually just `project.yml`) and errors only if *nothing* is tracked. |
| `release`/`release_quick` errors with "run `bundle exec fastlane setup_secrets` first" | `ensure_secrets_ready` found required secrets missing from ENV — expected the first time, or if `setup_secrets` was never run. Not a bug to work around; go run it. |
| `collect-secrets.sh` prompts hang or produce garbled output when run through an agent/tool call | It was invoked through a non-interactive shell instead of directly by the user — `setup_secrets` is meant to be run by the user in a real terminal (SKILL.md scaffold step 2.6). |
| `setup_secrets` fails with "No such file … scripts/collect-secrets.sh" | The scripts weren't copied into the repo. They must be at `fastlane/scripts/` (scaffold step 4), not left in the skill folder — the Fastfile resolves them relative to `fastlane/`. |
| `Dotenv` not defined / `require "dotenv"` fails | It's `require`d lazily inside `ensure_secrets_collected` (not at file top, so `release_quick`/CI never load it). fastlane bundles the dotenv gem, so the require resolves; if it somehow doesn't, `bundle add dotenv`. |
