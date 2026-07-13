#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$SKILLS_DIR"

# Use the repo's versioned hooks (post-merge/post-checkout re-run this script),
# so new skills appear after a pull without a manual step — even on a fresh clone.
git -C "$REPO_DIR" config core.hooksPath hooks

# Prune links into this repo whose skill no longer exists.
for link in "$SKILLS_DIR"/*; do
  [[ -L "$link" ]] || continue
  [[ "$(readlink "$link")" == "$REPO_DIR"/* ]] || continue
  if [[ ! -f "$link/SKILL.md" ]]; then
    rm "$link"
    echo "  pruned $(basename "$link") (no longer a skill in the repo)"
  fi
done

for skill in "$REPO_DIR"/*/; do
  name="$(basename "$skill")"
  [[ -f "$skill/SKILL.md" ]] || continue  # only link actual skills, not e.g. hooks/

  target="$SKILLS_DIR/$name"

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "$skill" || "$current" == "${skill%/}" ]]; then
      echo "  ok  $name"
      continue
    fi
    rm "$target"
  elif [[ -e "$target" ]]; then
    echo "  skip $name (exists as non-symlink — remove manually to link)"
    continue
  fi

  ln -s "$skill" "$target"
  echo "  linked $name"
done
