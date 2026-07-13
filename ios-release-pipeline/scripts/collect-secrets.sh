#!/usr/bin/env bash
# Interactively collects the pipeline's 6 secrets and writes them to fastlane/.env.
# Run this yourself, directly in your own terminal -- not through an agent/assistant --
# so the values you type never pass through anything but this shell and the file below.
set -euo pipefail

ENV_FILE="fastlane/.env"
CERTS_REPO="${1:-}"

mkdir -p fastlane
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"  # holds all 6 secrets — keep it owner-only

set_var() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  grep -v "^${key}=" "$ENV_FILE" > "$tmp" 2>/dev/null || true
  echo "${key}=${value}" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
}

echo "This writes the 6 pipeline secrets to $ENV_FILE ($(pwd)/$ENV_FILE)."
echo "Nothing typed here is sent anywhere except that file."
echo

# --- MATCH_GIT_URL ---
if [[ -z "$CERTS_REPO" ]]; then
  read -rp "Certs repo name (e.g. myapp-certificates) or full git URL: " CERTS_REPO
fi
if [[ "$CERTS_REPO" == http* || "$CERTS_REPO" == git@* ]]; then
  match_git_url="$CERTS_REPO"
else
  match_git_url="$(gh repo view "$CERTS_REPO" --json url -q .url).git"
fi
set_var MATCH_GIT_URL "$match_git_url"
echo "  MATCH_GIT_URL = $match_git_url"

# --- MATCH_PASSWORD ---
match_password="$(openssl rand -base64 32)"
set_var MATCH_PASSWORD "$match_password"
echo "  MATCH_PASSWORD generated"

# --- ASC API key ---
cat <<'EOF'

--- App Store Connect API key ---
1. https://appstoreconnect.apple.com/access/integrations/api
2. Click + under "Team Keys", name it, set access to "App Manager"
3. Download the .p8 file now -- Apple only allows this once
EOF
read -rp "Key ID: " asc_key_id
read -rp "Issuer ID: " asc_issuer_id
read -rp "Path to downloaded .p8 file: " p8_path
p8_path="${p8_path/#\~/$HOME}"
[[ -f "$p8_path" ]] || { echo "No such file: $p8_path" >&2; exit 1; }
asc_key_content="$(base64 -i "$p8_path" | tr -d '\n')"
set_var ASC_KEY_ID "$asc_key_id"
set_var ASC_ISSUER_ID "$asc_issuer_id"
set_var ASC_KEY_CONTENT "$asc_key_content"
echo "  ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_CONTENT saved"

# --- GitHub PAT for the certs repo ---
cat <<'EOF'

--- GitHub token for the certs repo ---
1. https://github.com/settings/personal-access-tokens/new
2. Scope it (fine-grained) to just the certs repo, with Contents: Read and write
3. Generate it and copy the token now -- shown once
EOF
read -rsp "Paste the token (input hidden): " pat
echo
username="$(gh api user -q .login)"
match_git_basic_auth="$(printf '%s:%s' "$username" "$pat" | base64 | tr -d '\n')"  # GNU base64 wraps at 76 chars
set_var MATCH_GIT_BASIC_AUTHORIZATION "$match_git_basic_auth"
echo "  MATCH_GIT_BASIC_AUTHORIZATION saved"

echo
echo "Done. $ENV_FILE has all 6 vars."
