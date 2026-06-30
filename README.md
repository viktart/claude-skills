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

## Structure

Each skill is a directory with two files:

```
<skill-name>/
  skill.md       # Instructions loaded when the skill is invoked
  reference.md   # Supporting detail linked from skill.md
```

## Installation

Clone the repo and run the install script:

```bash
git clone <repo-url> ~/Developer/claude-skills
cd ~/Developer/claude-skills
./install.sh
```

`install.sh` creates a symlink in `~/.claude/skills/` for every skill directory in the repo. Skills already linked correctly are left untouched; non-symlink entries are skipped with a warning so nothing is overwritten silently.

Git hooks (`post-merge`, `post-checkout`) run `install.sh` automatically after `git pull` or branch switches, so new skills added to the repo appear in Claude Code without any manual step.

## Adding a new skill

1. Create a directory with `skill.md` (and optionally `reference.md`)
2. Run `./install.sh` — the symlink is created and the skill is immediately available
