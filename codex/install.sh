#!/usr/bin/env bash
set -euo pipefail

MODE="link"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)
      MODE="copy"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    *)
      echo "usage: ./codex/install.sh [--copy] [--force]" >&2
      exit 1
      ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_SRC="$ROOT/codex/skills"
AGENTS_SRC="$ROOT/codex/agents"
SKILLS_DST="$HOME/.codex/skills"
AGENTS_DST="$HOME/.codex/agents"
STATE_DIR="$HOME/.codex/zuggie"
STATE_FILE="$STATE_DIR/install-manifest.txt"

mkdir -p "$SKILLS_DST" "$AGENTS_DST" "$STATE_DIR"

touch "$STATE_FILE"

record_install() {
  local dst="$1"
  if ! grep -Fqx "$dst" "$STATE_FILE"; then
    printf '%s\n' "$dst" >> "$STATE_FILE"
  fi
}

is_same_symlink() {
  local src="$1"
  local dst="$2"
  [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]
}

copy_matches_source() {
  local src="$1"
  local dst="$2"
  if [[ -d "$src" && -d "$dst" ]]; then
    diff -qr "$src" "$dst" >/dev/null 2>&1
    return $?
  fi
  if [[ -f "$src" && -f "$dst" ]]; then
    cmp -s "$src" "$dst"
    return $?
  fi
  return 1
}

install_path() {
  local src="$1"
  local dst="$2"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$MODE" == "link" ]] && is_same_symlink "$src" "$dst"; then
      echo "unchanged: $dst"
      record_install "$dst"
      return 0
    fi

    if [[ "$MODE" == "copy" ]] && copy_matches_source "$src" "$dst"; then
      echo "unchanged: $dst"
      record_install "$dst"
      return 0
    fi

    if [[ "$FORCE" -ne 1 ]]; then
      echo "skip: $dst already exists; rerun with --force to replace it" >&2
      return 0
    fi

    rm -rf "$dst"
  fi

  if [[ "$MODE" == "copy" ]]; then
    cp -R "$src" "$dst"
  else
    ln -s "$src" "$dst"
  fi

  record_install "$dst"
  echo "installed: $dst"
}

install_path "$SKILLS_SRC/zuggie" "$SKILLS_DST/zuggie"
install_path "$SKILLS_SRC/zuggie-structured-debug" "$SKILLS_DST/zuggie-structured-debug"
install_path "$AGENTS_SRC/zuggie-tech-lead.toml" "$AGENTS_DST/zuggie-tech-lead.toml"
install_path "$AGENTS_SRC/zuggie-engineer.toml" "$AGENTS_DST/zuggie-engineer.toml"
install_path "$AGENTS_SRC/zuggie-reviewer.toml" "$AGENTS_DST/zuggie-reviewer.toml"
install_path "$AGENTS_SRC/zuggie-debugger.toml" "$AGENTS_DST/zuggie-debugger.toml"

echo "Completed zuggie Codex install in $MODE mode:"
echo "  skills  -> $SKILLS_DST"
echo "  agents  -> $AGENTS_DST"
echo "  manifest -> $STATE_FILE"
