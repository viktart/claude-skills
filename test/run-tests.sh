#!/usr/bin/env bash
# Layer 1: deterministic tests — no LLM, no Xcode. Runs in CI on every push
# and locally via ./test/run-tests.sh. Agentic scenarios live in run-scenarios.sh.
set -uo pipefail

cd "$(dirname "$0")" || exit 1
fail=0

for t in unit/*.sh; do
  echo "--- $t"
  if bash "$t"; then
    echo "PASS $t"
  else
    echo "FAIL $t"
    fail=1
  fi
done

exit "$fail"
