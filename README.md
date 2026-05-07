# Zuggie RAC Config Pack

Zuggie is now distributed as a RAC shared config pack.

## Install

```bash
rac pack add zuggie github:raniejade/zuggie --ref <ref>
rac install --target claude,codex --kind agent,skill
```

## Supported targets

- `claude`
- `codex`

## Supported kinds

- `agent`
- `skill`

## Source of truth

All generated vendor config now comes from `.rac/` in this repository:

- `.rac/config.toml`
- `.rac/agents/*.toml`
- `.rac/agents/*.tpl.md`
- `.rac/skills/*/SKILL.tpl.md`

## Generated output locations

`rac install --target claude,codex --kind agent,skill` generates into standard vendor locations in the target project:

- Claude agents/skills under `.claude/`
- Codex agents under `.codex/agents/`
- Codex skills under `.agents/skills/`

## Validation workflow

Use RAC structural validation commands:

```bash
npx github:raniejade/rac doctor --target claude,codex --kind agent,skill
npx github:raniejade/rac install --target claude,codex --kind agent,skill --dry-run
```

## Cutover policy

This repository has a hard cutover to RAC packaging. Legacy plugin-era and direct Codex packaging surfaces were removed with no compatibility layer.
