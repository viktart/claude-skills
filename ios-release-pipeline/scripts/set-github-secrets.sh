#!/usr/bin/env bash
# Pushes the 6 pipeline secrets from a local fastlane/.env to GitHub repo secrets.
# Values never pass through anything but this shell — read straight from .env, sent straight to `gh`.
set -euo pipefail

ENV_FILE="${1:-fastlane/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — populate it first (see certs-bootstrap.md)." >&2
  exit 1
fi

REQUIRED_KEYS=(ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT MATCH_GIT_URL MATCH_PASSWORD MATCH_GIT_BASIC_AUTHORIZATION)

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for key in "${REQUIRED_KEYS[@]}"; do
  value="${!key:-}"
  if [[ -z "$value" ]]; then
    echo "Missing $key in $ENV_FILE — aborting before setting anything else." >&2
    exit 1
  fi
done

for key in "${REQUIRED_KEYS[@]}"; do
  gh secret set "$key" --body "${!key}"
  echo "  set $key"
done
