#!/usr/bin/env bash
# install.sh: links skills, skips non-skills, prunes stale links, idempotent.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../helpers.sh"

export HOME="$TMP/home"
mkdir -p "$HOME"
SKILLS="$HOME/.claude/skills"

# fresh install links every skill dir, and nothing else
"$REPO/install.sh" >/dev/null
for s in ios-run-tests ios-update-test-docs ios-release-pipeline; do
  [[ -L "$SKILLS/$s" ]] || { echo "not linked: $s" >&2; exit 1; }
  assert_file "$SKILLS/$s/SKILL.md"
done
[[ ! -e "$SKILLS/hooks" ]] || { echo "hooks/ must not be linked as a skill" >&2; exit 1; }
[[ ! -e "$SKILLS/test" ]] || { echo "test/ must not be linked as a skill" >&2; exit 1; }

# second run is idempotent
out="$("$REPO/install.sh")"
grep -q "ok  ios-run-tests" <<<"$out" || { echo "second run relinked instead of ok" >&2; exit 1; }

# a non-symlink entry is skipped, never overwritten
rm "$SKILLS/ios-run-tests"
mkdir "$SKILLS/ios-run-tests"
touch "$SKILLS/ios-run-tests/keep"
out="$("$REPO/install.sh")"
grep -q "skip ios-run-tests" <<<"$out" || { echo "non-symlink not skipped" >&2; exit 1; }
assert_file "$SKILLS/ios-run-tests/keep"
rm -rf "$SKILLS/ios-run-tests"

# stale links into this repo are pruned; links elsewhere are left alone
ln -s "$REPO/no-such-skill" "$SKILLS/ghost"
ln -s "$TMP" "$SKILLS/foreign"
out="$("$REPO/install.sh")"
grep -q "pruned ghost" <<<"$out" || { echo "stale link not pruned" >&2; exit 1; }
[[ ! -L "$SKILLS/ghost" ]] || { echo "ghost link still present" >&2; exit 1; }
[[ -L "$SKILLS/foreign" ]] || { echo "foreign link was removed" >&2; exit 1; }
[[ -L "$SKILLS/ios-run-tests" ]] || { echo "skill not relinked after cleanup" >&2; exit 1; }
