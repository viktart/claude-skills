#!/usr/bin/env bash
# Workflow YAML files parse (repo CI + the ios-release.yml template).
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../helpers.sh"

if ! command -v ruby >/dev/null 2>&1; then
  echo "  warn ruby not installed — skipping YAML parse checks" >&2
  exit 0
fi

for y in "$REPO/.github/workflows/lint.yml" \
         "$REPO/ios-release-pipeline/templates/ios-release.yml"; do
  ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$y" || { echo "invalid YAML: $y" >&2; exit 1; }
done
