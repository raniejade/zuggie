# Zuggie

A Claude Code plugin for structured development workflow. Non-trivial
work gets a dedicated worktree, a tech-lead plan, parallel engineer
implementation, and a reviewer pass — all from a single command.

## Commands

- /zuggie:implement <task> — run the full pipeline
- /zuggie:wt <branch> — create a git worktree

## How it works

/zuggie:implement runs a three-stage pipeline:

1. zuggie-tech-lead (opus) — plans the work and identifies parallel workstreams
2. zuggie-engineer (sonnet) — one per workstream, spawned in parallel where possible
3. zuggie-reviewer (opus) — reviews the diff, zuggie triages issues and fixes blockers

The main agent can also invoke /zuggie:implement automatically when
a conversation converges on a clear plan — you do not have to type it
yourself.

The PreToolUse hook acts as a safety net: if you start editing files
on main or master directly, zuggie will remind you to use a worktree.

## Installation

    /plugin marketplace add your-username/zuggie
    /plugin install zuggie@your-username

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
        "zuggie@your-username": false
      }
    }
