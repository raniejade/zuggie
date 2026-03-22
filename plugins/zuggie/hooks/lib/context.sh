#!/bin/bash
# Shared context library for zuggie hooks.
# This file should be sourced, not executed directly.

# zuggie_find_context_file "$dir"
# Walks up from dir to find .zuggie-context.json.
# Prints the path if found, returns 0. Returns 1 if not found.
zuggie_find_context_file() {
  local dir="$1"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/.zuggie-context.json" ]; then
      echo "$dir/.zuggie-context.json"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# zuggie_in_worktree "$dir"
# Returns 0 if a context file is found, 1 otherwise.
zuggie_in_worktree() {
  local dir="$1"
  zuggie_find_context_file "$dir" > /dev/null 2>&1
}

# zuggie_worktree_root "$dir"
# Prints the directory containing the context file. Returns 0 if found, 1 otherwise.
zuggie_worktree_root() {
  local dir="$1"
  local ctx_file
  ctx_file=$(zuggie_find_context_file "$dir") || return 1
  dirname "$ctx_file"
}

# zuggie_read_context "$dir"
# Prints the context JSON contents. Returns 0 if found, 1 otherwise.
zuggie_read_context() {
  local dir="$1"
  local ctx_file
  ctx_file=$(zuggie_find_context_file "$dir") || return 1
  cat "$ctx_file"
}
