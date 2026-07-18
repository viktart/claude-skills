#!/usr/bin/env bash
set -euo pipefail
command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen required (brew install xcodegen)" >&2; exit 2; }
xcodegen generate >/dev/null
