#!/bin/bash
# Guard git commands to ensure worktree discipline.
set +H

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/context.sh
source "$SCRIPT_DIR/lib/context.sh"

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Block git add/commit on main/master (branch check, not cwd)
branch=$(cd "$cwd" && git branch --show-current 2>/dev/null)
if echo "$cmd" | grep -qE 'git\s+(commit|add)\b' && [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo '{"decision":"block","reason":"Cannot git add/commit on main/master. cd into a worktree first."}'
  exit 0
fi

# Block other mutating git commands when not in a worktree
if ! zuggie_in_worktree "$cwd" && echo "$cmd" | grep -qE 'git\s+(push|merge|rebase|reset|cherry-pick|rm|mv|restore|clean)'; then
  echo '{"decision":"block","reason":"Mutating git commands must run inside a worktree. cd into .claude/zuggie/<branch> first."}'
fi
