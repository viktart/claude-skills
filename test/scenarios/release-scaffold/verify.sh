#!/usr/bin/env bash
# Post-conditions for /ios-release-pipeline scaffold. Runs in the scenario workdir.
set -uo pipefail
fail=0

need() { [[ -e "$1" ]] || { echo "missing: $1" >&2; fail=1; }; }

need fastlane/Fastfile
need fastlane/Appfile
need fastlane/.env.example
need .github/workflows/ios-release.yml
for s in collect-secrets.sh set-github-secrets.sh check-workflow-permissions.sh; do
  [[ -x "fastlane/scripts/$s" ]] || { echo "missing or not executable: fastlane/scripts/$s" >&2; fail=1; }
done

# the single highest-value assertion: no template token survived scaffolding
if grep -rnE '<[A-Za-z_]+>' fastlane/Fastfile fastlane/Appfile 2>/dev/null; then
  echo "unsubstituted placeholder tokens remain" >&2
  fail=1
fi

grep -q 'fastlane/\.env' .gitignore || { echo "fastlane/.env not gitignored" >&2; fail=1; }
[[ ! -f fastlane/.env ]] || { echo "a real fastlane/.env was written — must never happen at scaffold" >&2; fail=1; }

if [[ -f fastlane/Fastfile ]]; then
  ruby -c fastlane/Fastfile >/dev/null || { echo "Fastfile is not valid Ruby" >&2; fail=1; }
  grep -qE 'SIMULATOR_NAME = "iPhone' fastlane/Fastfile || { echo "SIMULATOR_NAME not set to an iPhone simulator" >&2; fail=1; }
  grep -q 'USES_XCODEGEN = true' fastlane/Fastfile || { echo "USES_XCODEGEN should be true for the fixture" >&2; fail=1; }
fi
grep -q 'TESTTEAM12' fastlane/Appfile 2>/dev/null || { echo "team ID not the instructed one" >&2; fail=1; }

exit "$fail"
