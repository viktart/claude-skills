# Certs repo bootstrap (fastlane `match`)

One command does the whole chain: `bundle exec fastlane setup_certs`, run **by the user, directly in their own terminal** (never through a tool call — it needs a real TTY for the interactive prompts below). Here's what it does internally, in order.

## 1. `ensure_secrets_collected`

Checks `MATCH_GIT_URL`, `MATCH_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` in ENV (loaded from `fastlane/.env`). If any are missing, it launches `fastlane/scripts/collect-secrets.sh` via Ruby's `system`, which inherits the real terminal — not the `sh` action, which pipes output for logging and can break interactive `read` prompts.

`collect-secrets.sh` then:
- Prompts for the certs-repo name (or full git URL) and derives `MATCH_GIT_URL` from it — the repo is named here, not duplicated into the Fastfile. Generates `MATCH_PASSWORD` (random) automatically.
- Prints the exact App Store Connect steps (create a Team Key with App Manager access, download the `.p8` once — Apple has no API for this, web UI only) and prompts for Key ID, Issuer ID, and the `.p8` path. Reads and base64-encodes the file itself.
- Prints the exact GitHub steps (fine-grained PAT scoped to the certs repo, Contents: Read and write — GitHub has no API to mint a token either) and prompts for it with hidden input (`read -s`). The username is fetched automatically via `gh api user`, not asked. Writes `MATCH_GIT_BASIC_AUTHORIZATION` (the base64 `user:token`) for CI to clone the private certs repo.

Once the script exits, the lane reloads `fastlane/.env` into the process (`Dotenv.overload`) so the freshly-written values are visible to the rest of the lane.

## 2. `match`

Creates the actual distribution certificate and provisioning profile via the App Store Connect API key, pushes them encrypted to the certs repo. This is the one part of `setup_certs` with real, only-partly-reversible side effects (consumes one of Apple's limited cert slots) — the calling skill confirms with the user before telling them to run the lane at all, precisely because this step is in it.

## 3. `push_secrets_to_github`

Runs `fastlane/scripts/set-github-secrets.sh` automatically — reads `fastlane/.env`, calls `gh secret set` for each of the 6 keys. No separate confirmation inside the lane; running `setup_certs` at all is already the user's one deliberate go-ahead for the whole chain.

## 4. `check_workflow_permissions`

Runs `fastlane/scripts/check-workflow-permissions.sh` — read-only warning if the repo's default `GITHUB_TOKEN` permissions could block the version-bump push later (see [reference.md](reference.md) gotchas). Never fails the lane.

---

Re-running `setup_certs` later (e.g. to renew an expired cert) is safe — `ensure_secrets_collected` is a no-op once `fastlane/.env` is already populated, so it goes straight to `match` → push secrets → preflight.
