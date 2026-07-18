# shellcheck shell=bash
# Shared helpers, sourced by test/unit/*.sh. Each test file gets its own
# temp dir (cleaned on exit) and the repo root in $REPO.

# shellcheck disable=SC2034  # REPO is used by the sourcing test files
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_eq() {  # actual expected [context]
  if [[ "$1" != "$2" ]]; then
    echo "ASSERT${3:+ $3}: expected '$2', got '$1'" >&2
    exit 1
  fi
}

assert_file() {
  [[ -e "$1" ]] || { echo "ASSERT: missing file $1" >&2; exit 1; }
}

file_mode() {  # portable stat: BSD (macOS) first, then GNU
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

b64_decode() {  # portable base64 decode of a single-line value on stdin
  openssl base64 -d -A
}
