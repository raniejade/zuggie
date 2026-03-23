#!/bin/bash
# Block Edit/Write to files outside the current worktree when cwd is inside one.
set +H

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/context.sh
source "$SCRIPT_DIR/lib/context.sh"

input=$(cat)
path=$(echo "$input" | jq -r '.tool_input.file_path')
cwd=$(echo "$input" | jq -r '.cwd // empty')

worktree_root=$(zuggie_worktree_root "$cwd") || exit 0

if [[ "$path" != "$worktree_root"/* ]]; then
  echo '{"decision":"block","reason":"You are in a worktree but editing a file outside it. Use the worktree copy of this file instead."}'
else
  echo '{"decision":"allow"}'
fi
