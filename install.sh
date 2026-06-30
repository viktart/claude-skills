#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$SKILLS_DIR"

for skill in "$REPO_DIR"/*/; do
  name="$(basename "$skill")"
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
