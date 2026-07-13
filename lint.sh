#!/usr/bin/env bash
# Repo lint: shellcheck all scripts, check every skill dir has a SKILL.md with
# name/description frontmatter, and verify relative markdown links resolve.
# Run locally or via .github/workflows/lint.yml.
set -uo pipefail

cd "$(dirname "$0")"
fail=0

# --- shell scripts ---
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh lint.sh hooks/post-merge hooks/post-checkout \
    ios-release-pipeline/scripts/*.sh || fail=1
else
  echo "  warn shellcheck not installed — skipping shell lint" >&2
fi

# --- skill structure ---
for dir in */; do
  name="${dir%/}"
  case "$name" in hooks) continue ;; esac

  if [[ ! -f "${dir}SKILL.md" ]]; then
    echo "FAIL: $name/ has no SKILL.md" >&2
    fail=1
    continue
  fi
  if ! awk 'NR==1 && $0=="---" {f=1} f && /^name: /{n=1} f && /^description: /{d=1} END{exit !(n && d)}' "${dir}SKILL.md"; then
    echo "FAIL: $name/SKILL.md frontmatter is missing name: or description:" >&2
    fail=1
  fi
done

# --- relative markdown links resolve ---
while IFS=$'\t' read -r file link; do
  case "$link" in
    http*|mailto:*|"#"*) continue ;;
  esac
  target="${link%%#*}"
  if [[ ! -e "$(dirname "$file")/$target" ]]; then
    echo "FAIL: $file — broken link: $link" >&2
    fail=1
  fi
done < <(grep -RoE '\[[^]]*\]\([^)]+\)' --include='*.md' . 2>/dev/null \
  | sed -E 's/^([^:]+):\[[^]]*\]\(([^)]+)\)$/\1\t\2/')

if [[ "$fail" -eq 0 ]]; then
  echo "  ok  lint passed"
fi
exit "$fail"
