#!/usr/bin/env bash
# Layer 2: agentic scenarios — spawns headless Claude Code against a disposable
# copy of test/fixtures/DemoApp and asserts post-conditions with each scenario's
# verify.sh. Run LOCALLY on a Mac (needs Xcode, xcodegen, a simulator, and
# Claude Code auth). Costs tokens and minutes — deliberately NOT run in CI.
#
# Usage: ./test/run-scenarios.sh [scenario ...]   (default: all)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/test/fixtures/DemoApp"

scenarios=("$@")
if [[ ${#scenarios[@]} -eq 0 ]]; then
  scenarios=(release-scaffold test-docs-and-run)
fi

fail=0
for name in "${scenarios[@]}"; do
  dir="$ROOT/test/scenarios/$name"
  if [[ ! -d "$dir" ]]; then
    echo "unknown scenario: $name (expected a directory in test/scenarios/)" >&2
    exit 2
  fi

  work="$(mktemp -d "${TMPDIR:-/tmp}/skill-scenario-$name.XXXXXX")"
  cp -R "$FIXTURE/." "$work/"
  git -C "$work" init -q
  git -C "$work" add -A
  git -C "$work" -c user.name=fixture -c user.email=fixture@example.com commit -qm "fixture"

  if [[ -x "$dir/setup.sh" ]]; then
    (cd "$work" && "$dir/setup.sh") || { echo "SKIP $name (setup failed — missing prerequisite?)"; fail=1; continue; }
  fi

  echo "=== $name — workdir: $work"
  # --dangerously-skip-permissions: the workdir is disposable, but the agent can
  # still touch shared state (simulators, /tmp) — review prompt.md before adding scenarios.
  (cd "$work" && claude -p "$(cat "$dir/prompt.md")" --dangerously-skip-permissions) \
    | tee "$work/transcript.txt" || true

  if (cd "$work" && "$dir/verify.sh"); then
    echo "PASS $name"
  else
    echo "FAIL $name — inspect $work (transcript.txt has the agent's output)"
    fail=1
  fi
done

exit "$fail"
