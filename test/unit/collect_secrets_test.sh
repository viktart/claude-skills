#!/usr/bin/env bash
# collect-secrets.sh: writes all 3 keys to fastlane/.env (mode 600), base64
# values are single-line and round-trip, re-running replaces instead of appending.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../helpers.sh"

SCRIPT="$REPO/ios-release-pipeline/scripts/collect-secrets.sh"
cd "$TMP"

printf 'FAKEP8KEYCONTENT' > key.p8

bash "$SCRIPT" >/dev/null <<EOF
KEYID123
ISSUER-456
$TMP/key.p8
EOF

ENVF="fastlane/.env"
assert_file "$ENVF"
assert_eq "$(file_mode "$ENVF")" "600" "(.env permissions)"

for k in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT; do
  grep -q "^$k=" "$ENVF" || { echo "missing $k in .env" >&2; exit 1; }
done

# base64 value round-trips and is single-line (no GNU 76-char wrapping)
content="$(grep '^ASC_KEY_CONTENT=' "$ENVF" | cut -d= -f2-)"
assert_eq "$(printf '%s' "$content" | b64_decode)" "FAKEP8KEYCONTENT" "(ASC_KEY_CONTENT round-trip)"

# re-running replaces values in place, never duplicates keys
bash "$SCRIPT" >/dev/null <<EOF
NEWKEY999
ISSUER-456
$TMP/key.p8
EOF
assert_eq "$(grep -c '^ASC_KEY_ID=' "$ENVF")" "1" "(single ASC_KEY_ID line)"
grep -q '^ASC_KEY_ID=NEWKEY999$' "$ENVF" || { echo "re-run did not update ASC_KEY_ID" >&2; exit 1; }
