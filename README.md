# Claude Skills

Personal Claude Code skills for iOS development workflows.

## Skills

### `ios-run-tests`

Runs iOS XCUITest tests on a simulator, extracts XCTAttachment screenshots from the xcresult bundle, displays them, and reports pass/fail with failure details.

**Invoke:** `/ios-run-tests [scope]`

| Argument | Runs |
|----------|------|
| _(blank)_ | All tests in the UI test target |
| `ClassName` | All methods in that class |
| `ClassName/methodName` | Single test method |
| `build ClassName/methodName` | Force rebuild, then run |

Reads simulator UDID, scheme, test target, and bundle ID from the project's `CLAUDE.md`. If any are missing, it runs `/ios-update-test-docs` first.

---

### `ios-update-test-docs`

Discovers an iOS Xcode project's test configuration and writes it into the project's `CLAUDE.md` so future sessions skip re-discovery.

**Invoke:** `/ios-update-test-docs`

Writes two sections into `CLAUDE.md` — **Build & Test** and **UI Testing** — covering the simulator, bundle ID, ready-to-paste `xcodebuild` commands, and the full list of test targets → classes → methods. All other `CLAUDE.md` sections are left untouched.

Run this once when setting up a new iOS project, after switching simulators, or when the `CLAUDE.md` test info is stale.

---

### `ios-release-pipeline`

Scaffolds and runs a Fastlane-based release pipeline: bump semantic version → run tests → archive → upload to TestFlight → commit/tag/push the version bump.

**Invoke:** `/ios-release-pipeline [scaffold | patch | minor | major | quick]`

| Argument | Behaviour |
|----------|-----------|
| _(blank)_ | Detect setup; scaffold if missing, otherwise run the full lane with a patch bump |
| `scaffold` | (Re-)install `fastlane/` files and the GitHub Actions workflow into the current repo |
| `patch` / `minor` / `major` | Run the full local lane (bump → test → build → upload → push) with that bump type |
| `quick` | Run the partial lane (same, minus the test step) — normally triggered via the GitHub Action instead |

Scaffolding asks which simulator to run tests against (never assumes one), writes a `Fastfile`/`Appfile`/`Matchfile`, a `.github/workflows/ios-release.yml` (manual `workflow_dispatch`), and checks for a companion `<repo>-certificates` repo used by `fastlane match` for code signing — asking before creating one. All 6 required secrets are then handled by a single command you run yourself, directly in your terminal: `bundle exec fastlane setup_certs`. That lane collects any missing secrets interactively (prompting only for the two credentials Apple/GitHub require creating through their web UI — an ASC API key, a certs-repo token — so nothing else gets typed into the conversation), bootstraps the cert, and pushes everything to GitHub in one go. The release lanes themselves check the certs repo is bootstrapped before doing anything and point back at `setup_certs` if it isn't, instead of failing with a cryptic signing error.

## Structure

Each skill is a directory with `SKILL.md` as the entry point (uppercase — the official skill format; lowercase only works on case-insensitive filesystems), optionally alongside supporting files it links to:

```
<skill-name>/
  SKILL.md         # Instructions loaded when the skill is invoked
  reference.md     # Supporting detail linked from SKILL.md
  templates/       # Literal files to copy/adapt, when a skill scaffolds files into other repos
  other-topic.md   # Further split-out docs for large or multi-domain skills
```

Keep `SKILL.md` short and split out anything long or self-contained (design notes, gotchas, file templates) into its own file — easier to review than one large `reference.md`.

## Installation

Clone the repo and run the install script:

```bash
git clone <repo-url> ~/Developer/claude-skills
cd ~/Developer/claude-skills
./install.sh
```

`install.sh` creates a symlink in `~/.claude/skills/` for every directory in the repo containing a `SKILL.md`. Skills already linked correctly are left untouched; non-symlink entries are skipped with a warning so nothing is overwritten silently; links into this repo whose skill was deleted are pruned.

It also points `core.hooksPath` at the versioned [hooks/](hooks/) directory, whose `post-merge`/`post-checkout` hooks re-run `install.sh` after `git pull` or branch switches — so new skills appear in Claude Code without any manual step, on any clone.

## Adding a new skill

1. Create a directory with `SKILL.md` (and optionally `reference.md`)
2. Run `./install.sh` — the symlink is created and the skill is immediately available
3. `./lint.sh` (also run in CI) checks shell scripts, `SKILL.md` frontmatter, and that relative markdown links resolve
