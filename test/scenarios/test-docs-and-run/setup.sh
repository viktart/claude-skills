#!/usr/bin/env bash
set -euo pipefail
command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen required (brew install xcodegen)" >&2; exit 2; }
xcodegen generate >/dev/null
# stale screenshots from earlier runs would make verify.sh pass vacuously
rm -f /tmp/xctest_*.png
