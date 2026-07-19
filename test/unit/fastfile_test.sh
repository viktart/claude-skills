#!/usr/bin/env bash
# Fastfile template: renders to valid Ruby with all placeholders substituted,
# and every template's placeholder set matches what reference.md documents.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../helpers.sh"

TEMPLATES="$REPO/ios-release-pipeline/templates"
REF="$REPO/ios-release-pipeline/reference.md"
cd "$TMP"

sed -e 's/<Scheme>/DemoApp/g' \
    -e 's/<AppTarget>/DemoApp/g' \
    -e 's/<XcodeprojName>/DemoApp/g' \
    -e 's/<UnitTestTarget>/DemoAppTests/g' \
    -e 's/<true_or_false>/true/g' \
    -e 's/<SimulatorName>/iPhone 16/g' \
    "$TEMPLATES/Fastfile" > Fastfile

if grep -nE '<[A-Za-z_]+>' Fastfile; then
  echo "unsubstituted placeholder tokens remain — template gained a placeholder this test doesn't know" >&2
  exit 1
fi

if command -v ruby >/dev/null 2>&1; then
  ruby -c Fastfile >/dev/null
else
  echo "  warn ruby not installed — skipping Fastfile syntax check" >&2
fi

# placeholder drift: tokens in each template == tokens documented in reference.md's table
for tpl in Fastfile Appfile env.example ios-release.yml; do
  file_tokens="$(grep -ohE '<[A-Za-z_]+>' "$TEMPLATES/$tpl" | sort -u || true)"
  doc_row="$(grep -E "^\| \[templates/$tpl\]" "$REF" || true)"
  [[ -n "$doc_row" ]] || { echo "reference.md table has no row for templates/$tpl" >&2; exit 1; }
  doc_tokens="$(grep -ohE '<[A-Za-z_]+>' <<<"$doc_row" | sort -u || true)"
  assert_eq "$file_tokens" "$doc_tokens" "(placeholder drift: templates/$tpl vs reference.md)"
done
