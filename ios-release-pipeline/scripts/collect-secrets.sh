#!/usr/bin/env bash
# Interactively collects the pipeline's 3 secrets and writes them to fastlane/.env.
# Run this yourself, directly in your own terminal -- not through an agent/assistant --
# so the values you type never pass through anything but this shell and the file below.
set -euo pipefail

ENV_FILE="fastlane/.env"

mkdir -p fastlane
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"  # holds all 3 secrets — keep it owner-only

set_var() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  grep -v "^${key}=" "$ENV_FILE" > "$tmp" 2>/dev/null || true
  echo "${key}=${value}" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
}

echo "This writes the 3 pipeline secrets to $ENV_FILE ($(pwd)/$ENV_FILE)."
echo "Nothing typed here is sent anywhere except that file."
echo

# --- ASC API key ---
cat <<'EOF'
--- App Store Connect API key ---
1. https://appstoreconnect.apple.com/access/integrations/api
2. Click + under "Team Keys", name it, set access to "App Manager"
   (cloud signing needs App Manager or higher)
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

echo
echo "Done. $ENV_FILE has all 3 vars. Keep the .p8 file (or this .env) backed up somewhere"
echo "safe -- Apple never lets you re-download the key."
