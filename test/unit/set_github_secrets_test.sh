#!/usr/bin/env bash
# set-github-secrets.sh: pushes all 6 secrets via gh; a missing key aborts
# before setting anything.
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/../helpers.sh"

SCRIPT="$REPO/ios-release-pipeline/scripts/set-github-secrets.sh"
cd "$TMP"

mkdir -p bin fastlane
cat > bin/gh <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$GH_LOG"
EOF
chmod +x bin/gh
export PATH="$TMP/bin:$PATH" GH_LOG="$TMP/gh.log"
touch "$GH_LOG"

cat > fastlane/.env <<'EOF'
ASC_KEY_ID=k
ASC_ISSUER_ID=i
ASC_KEY_CONTENT=c
MATCH_GIT_URL=u
MATCH_PASSWORD=p
MATCH_GIT_BASIC_AUTHORIZATION=b
EOF

bash "$SCRIPT" >/dev/null
assert_eq "$(grep -c '^secret set ' "$GH_LOG")" "6" "(all 6 secrets pushed)"

# a missing key aborts before any gh call
: > "$GH_LOG"
grep -v '^MATCH_PASSWORD=' fastlane/.env > e2 && mv e2 fastlane/.env
if bash "$SCRIPT" >/dev/null 2>&1; then
  echo "should have failed on missing MATCH_PASSWORD" >&2
  exit 1
fi
assert_eq "$(wc -l < "$GH_LOG" | tr -d ' ')" "0" "(no secrets set after abort)"
