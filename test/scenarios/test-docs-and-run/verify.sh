#!/usr/bin/env bash
# Post-conditions for /ios-update-test-docs + /ios-run-tests on the fixture.
set -uo pipefail
fail=0

[[ -f CLAUDE.md ]] || { echo "CLAUDE.md was not written" >&2; exit 1; }

grep -q '^## Build & Test' CLAUDE.md || { echo "missing '## Build & Test' section" >&2; fail=1; }
grep -q '^## UI Testing' CLAUDE.md || { echo "missing '## UI Testing' section" >&2; fail=1; }
grep -q 'com.example.DemoApp' CLAUDE.md || { echo "real bundle ID not recorded" >&2; fail=1; }
grep -qE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' CLAUDE.md || { echo "no simulator UDID recorded" >&2; fail=1; }
grep -q 'DemoAppUITests' CLAUDE.md || { echo "UI test target not recorded" >&2; fail=1; }

shots=(/tmp/xctest_*.png)
if [[ ! -e "${shots[0]}" ]]; then
  echo "no screenshots extracted to /tmp/xctest_*.png" >&2
  fail=1
elif ! file -b "${shots[0]}" | grep -q PNG; then
  echo "extracted screenshot is not a PNG" >&2
  fail=1
fi

exit "$fail"
