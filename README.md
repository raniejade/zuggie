# Zuggie

A Claude Code plugin for structured development workflow. Non-trivial
work gets a dedicated worktree, a tech-lead plan, parallel engineer
implementation, and a reviewer pass — all from a single command.

## Usage

    /zuggie <task description>

This runs a three-stage pipeline:

1. zuggie-tech-lead (opus) — plans the work and identifies parallel milestones
2. zuggie-engineer (sonnet) — one per milestone, spawned in parallel where possible
3. zuggie-reviewer (opus) — reviews the diff, zuggie triages issues and fixes blockers

## Installation

    /plugin marketplace add raniejade/zuggie
    /plugin install zuggie@zuggie

## Permissions

Zuggie auto-approves Edit, Write, and Bash tool calls when the working
directory is inside a zuggie worktree (`.claude/zuggie/<branch>`). This
prevents sub-agents from prompting for permission on every operation.

Outside a worktree, normal permission flow applies. Edits to files
outside the active worktree are blocked, and git add/commit on
main/master is always blocked.

## Customisation

### Agent models

Defaults:
- zuggie-tech-lead — opus
- zuggie-engineer — sonnet
- zuggie-reviewer — opus

To override, create .claude/agents/zuggie-<role>.md in your project
with the same name field (e.g. name: zuggie-engineer) and your
preferred model. The local file takes precedence over the plugin.
The name field must match exactly for the override to take effect.

### Agent behaviour

Same mechanism — shadow any agent file to change its system prompt,
restrict its tools, or adjust instructions for your team's conventions.

### Disabling the plugin for a project

Add to .claude/settings.local.json:

    {
      "enabledPlugins": {
        "zuggie@zuggie": false
      }
    }
