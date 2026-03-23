#!/bin/bash
# Guard git commands to ensure worktree discipline.
set +H

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/context.sh
source "$SCRIPT_DIR/lib/context.sh"

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Block compound commands (&&, ;, ||) that contain mutating git operations.
# The hook cannot reliably determine the cwd of a git command inside a
# compound expression. Force agents to cd first, then run git separately.
if echo "$cmd" | grep -qE '(&&|;|\|\|)' && echo "$cmd" | grep -qE 'git\s+(add|commit|push|merge|rebase|reset|cherry-pick|rm|mv|restore|clean)\b'; then
  echo '{"decision":"block","reason":"Do not combine cd and git in one command. Run cd first (to update cwd), then run the git command separately."}'
  exit 0
fi

# Block git add/commit on main/master (branch check, not cwd)
branch=$(cd "$cwd" && git branch --show-current 2>/dev/null)
if echo "$cmd" | grep -qE 'git\s+(commit|add)\b' && [[ "$branch" == "main" || "$branch" == "master" ]]; then
  echo '{"decision":"block","reason":"Cannot git add/commit on main/master. cd into a worktree first."}'
  exit 0
fi

# Block other mutating git commands when not in a worktree
if ! zuggie_in_worktree "$cwd" && echo "$cmd" | grep -qE 'git\s+(push|merge|rebase|reset|cherry-pick|rm|mv|restore|clean)'; then
  echo '{"decision":"block","reason":"Mutating git commands must run inside a worktree. cd into .claude/zuggie/<branch> first."}'
  exit 0
fi

# Auto-approve when inside a worktree (sandbox constrains filesystem/network)
if zuggie_in_worktree "$cwd"; then
  echo '{"decision":"allow"}'
fi
