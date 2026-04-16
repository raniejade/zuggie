#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.codex/zuggie/install-manifest.txt"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "No zuggie install manifest found at $STATE_FILE"
  exit 0
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if [[ -L "$path" || -e "$path" ]]; then
    rm -rf "$path"
    echo "removed: $path"
  fi
done < "$STATE_FILE"

rm -f "$STATE_FILE"

echo "Removed zuggie Codex skills and subagents from user scope."
