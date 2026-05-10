# Zuggie

Structured planning, implementation, and review pipeline for Claude Code and Codex, distributed as a RAC config pack.

## What you get

- `/zuggie` — Run the full planning, implementation, and review pipeline.
- `/zuggie-plan` — Planning-only zuggie role for creating or revising implementation plans.
- `/zuggie-structured-debug` — Structured debugging workflow using zuggie's dedicated debugger and reviewer subagents.
  - Agents: `zuggie-tech-lead`, `zuggie-engineer`, `zuggie-reviewer`, `zuggie-debugger`.

## Prerequisites

- Claude Code and/or Codex CLI.
- RAC CLI — Node 20 or later required. Install/run via `npx github:raniejade/rac`. See https://github.com/raniejade/rac.

## Install

```bash
rac pack add zuggie github:raniejade/zuggie --ref <ref>
rac install --target claude,codex --kind agent,skill
```

`<ref>` is currently a commit SHA or branch name — no release tag exists yet.

## Generated output locations

`rac install --target claude,codex --kind agent,skill` generates into standard vendor locations in the target project:

- Claude agents/skills under `.claude/`
- Codex agents under `.codex/agents/`
- Codex skills under `.agents/skills/`

## Usage

```
/zuggie add foo to bar
/zuggie-plan refactor X
/zuggie-structured-debug Y fails when Z
```

## Validation

```bash
npx github:raniejade/rac doctor --target claude,codex --kind agent,skill
npx github:raniejade/rac install --target claude,codex --kind agent,skill --dry-run
```

CI runs these same checks on every PR and push to main.

## Source of truth

- `.rac/config.toml`
- `.rac/agents/*.toml`
- `.rac/agents/*.tpl.md`
- `.rac/skills/*/SKILL.tpl.md`

## License

MIT — see [LICENSE](LICENSE).
