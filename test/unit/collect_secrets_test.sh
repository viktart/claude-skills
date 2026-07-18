#!/usr/bin/env bash
# collect-secrets.sh: writes all 6 keys to fastlane/.env (mode 600), base64
# values are single-line and round-trip, re-running replaces instead of appending.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../helpers.sh"

SCRIPT="$REPO/ios-release-pipeline/scripts/collect-secrets.sh"
cd "$TMP"

mkdir -p bin
cat > bin/gh <<'EOF'
#!/usr/bin/env bash
case "$1" in
  repo) echo "https://github.com/testuser/demo-certificates" ;;
  api)  echo "testuser" ;;
esac
EOF
chmod +x bin/gh
export PATH="$TMP/bin:$PATH"

printf 'FAKEP8KEYCONTENT' > key.p8

bash "$SCRIPT" >/dev/null <<EOF
demo-certificates
KEYID123
ISSUER-456
$TMP/key.p8
sekret-token
EOF

ENVF="fastlane/.env"
assert_file "$ENVF"
assert_eq "$(file_mode "$ENVF")" "600" "(.env permissions)"

for k in MATCH_GIT_URL MATCH_PASSWORD ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT MATCH_GIT_BASIC_AUTHORIZATION; do
  grep -q "^$k=" "$ENVF" || { echo "missing $k in .env" >&2; exit 1; }
done
grep -q '^MATCH_GIT_URL=https://github.com/testuser/demo-certificates.git$' "$ENVF" \
  || { echo "MATCH_GIT_URL not derived from gh repo view" >&2; exit 1; }

# base64 values round-trip and are single-line (no GNU 76-char wrapping)
content="$(grep '^ASC_KEY_CONTENT=' "$ENVF" | cut -d= -f2-)"
assert_eq "$(printf '%s' "$content" | b64_decode)" "FAKEP8KEYCONTENT" "(ASC_KEY_CONTENT round-trip)"
auth="$(grep '^MATCH_GIT_BASIC_AUTHORIZATION=' "$ENVF" | cut -d= -f2-)"
assert_eq "$(printf '%s' "$auth" | b64_decode)" "testuser:sekret-token" "(basic auth round-trip)"

# re-running replaces values in place, never duplicates keys
bash "$SCRIPT" >/dev/null <<EOF
demo-certificates
NEWKEY999
ISSUER-456
$TMP/key.p8
sekret-token
EOF
assert_eq "$(grep -c '^ASC_KEY_ID=' "$ENVF")" "1" "(single ASC_KEY_ID line)"
grep -q '^ASC_KEY_ID=NEWKEY999$' "$ENVF" || { echo "re-run did not update ASC_KEY_ID" >&2; exit 1; }
