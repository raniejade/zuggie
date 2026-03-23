#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/context.sh"

if [ -z "$CLAUDE_ENV_FILE" ]; then
  exit 0
fi

# Read hook input (common fields: session_id, agent_id, cwd, etc.)
input=$(cat)
agent_id=$(echo "$input" | jq -r '.agent_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd="${cwd:-$PWD}"

# Export agent instance ID
[ -n "$agent_id" ] && echo "export ZUGGIE_AGENT_ID=\"$agent_id\"" >> "$CLAUDE_ENV_FILE"

# Export worktree context if in a worktree
ctx=$(zuggie_read_context "$cwd") || exit 0
wt_root=$(zuggie_worktree_root "$cwd") || true

branch=$(echo "$ctx" | jq -r '.branch // empty')
base_branch=$(echo "$ctx" | jq -r '.base_branch // empty')

[ -n "$branch" ] && echo "export ZUGGIE_BRANCH=\"$branch\"" >> "$CLAUDE_ENV_FILE"
[ -n "$base_branch" ] && echo "export ZUGGIE_BASE_BRANCH=\"$base_branch\"" >> "$CLAUDE_ENV_FILE"
[ -n "$wt_root" ] && echo "export ZUGGIE_WORKTREE_ROOT=\"$wt_root\"" >> "$CLAUDE_ENV_FILE"
