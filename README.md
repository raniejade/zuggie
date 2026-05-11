# Zuggie

Structured planning, implementation, and review pipeline for Claude Code and Codex, distributed as a RAC config pack.

## What you get

- `/zuggie-impl` — Implement and review a change end-to-end. Breaks work into milestones, implements them, and reviews.
- `/zuggie-spec` — Build an implementation spec for a change. Spec-only — does not implement code.
- `/zuggie-structured-debug` — Structured debugging workflow using zuggie's dedicated debugger and reviewer subagents.
- Agents: `zuggie-tech-lead`, `zuggie-engineer`, `zuggie-reviewer`, `zuggie-debugger`.

`zuggie-spec` answers "what and why" — produces a spec (design artifact). `zuggie-impl` answers "how" — breaks work into milestones, implements them, and reviews. They are independent and can be run standalone in either order.

## Prerequisites

- Claude Code and/or Codex CLI.
- RAC CLI — Node 20 or later required. Install/run via `npx github:raniejade/rac`. See https://github.com/raniejade/rac.

## Install

```bash
rac pack add zuggie github:raniejade/zuggie --ref <ref>
rac install --target claude,codex --kind agent,skill
```

Use ``--ref v<X.Y.Z>`` for a stable release (e.g. ``--ref v0.1.0``). See [Releases](https://github.com/raniejade/zuggie/releases) for available tags.

## Generated output locations

`rac install --target claude,codex --kind agent,skill` generates into standard vendor locations in the target project:

- Claude agents/skills under `.claude/`
- Codex agents under `.codex/agents/`
- Codex skills under `.agents/skills/`

## Usage

```
/zuggie-impl add foo to bar
/zuggie-spec refactor X
/zuggie-structured-debug Y fails when Z
```

## Validation

```bash
npx -y github:raniejade/rac doctor --target claude,codex --kind agent,skill
npx -y github:raniejade/rac install --target claude,codex --kind agent,skill --dry-run
```

CI runs these same checks on every PR and push to main.

## Contributing — changelog entries

Run `npx -y @changesets/cli@^2.27 add` and commit the resulting `.changeset/*.md` file alongside your change.
Include one for every PR that has a user-visible effect; omit it for pure docs or CI changes.

## Source of truth

- `.rac/config.toml`
- `.rac/agents/*.toml`
- `.rac/agents/*.tpl.md`
- `.rac/skills/*/SKILL.tpl.md`

## License

MIT — see [LICENSE](LICENSE).
