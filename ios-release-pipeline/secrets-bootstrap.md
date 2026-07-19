# Secrets bootstrap (App Store Connect API key)

One command does the whole chain: `bundle exec fastlane setup_secrets`, run **by the user, directly in their own terminal** (never through a tool call — it needs a real TTY for the interactive prompts below). Here's what it does internally, in order.

Signing itself needs no setup step at all: the pipeline uses Apple's **cloud signing** (`xcodebuild -allowProvisioningUpdates` + the API key), so the distribution certificate is created and held on Apple's servers automatically the first time a build runs. There is no local certificate, no keychain import, and no certs repo — the API key below is the only credential in the whole pipeline.

## 1. `ensure_secrets_collected`

Checks `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` in ENV (loaded from `fastlane/.env`). If any are missing, it launches `fastlane/scripts/collect-secrets.sh` via Ruby's `system`, which inherits the real terminal — not the `sh` action, which pipes output for logging and can break interactive `read` prompts.

`collect-secrets.sh` prints the exact App Store Connect steps (create a Team Key with **App Manager** access — cloud signing needs App Manager or higher; download the `.p8` once — Apple has no API for this, web UI only) and prompts for Key ID, Issuer ID, and the `.p8` path. Reads and base64-encodes the file itself, then reminds the user to keep the `.p8` backed up — Apple never lets you re-download it, and GitHub secrets can't be read back.

Once the script exits, the lane reloads `fastlane/.env` into the process (`Dotenv.overload`) so the freshly-written values are visible to the rest of the lane.

## 2. `push_secrets_to_github`

Runs `fastlane/scripts/set-github-secrets.sh` automatically — reads `fastlane/.env`, calls `gh secret set` for each of the 3 keys. No separate confirmation inside the lane; running `setup_secrets` at all is already the user's one deliberate go-ahead for the whole chain.

## 3. `check_workflow_permissions`

Runs `fastlane/scripts/check-workflow-permissions.sh` — read-only warning if the repo's default `GITHUB_TOKEN` permissions could block the version-bump push later (see [reference.md](reference.md) gotchas). Never fails the lane.

---

`setup_secrets` has **no Apple-side side effects** — nothing is created until the first release build runs. Re-running it later (e.g. after revoking and re-issuing the API key: delete the stale values from `fastlane/.env` first) is safe — `ensure_secrets_collected` is a no-op while `fastlane/.env` is fully populated, so it goes straight to push secrets → preflight.
