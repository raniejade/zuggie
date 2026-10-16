# Zuggie

Zuggie is a public RAC skill pack for structured AI development workflows, with explicit planning, implementation, review, and debug roles.

![Workflow diagram showing the default Zuggie flow from request to PR-ready branch, with explorer subagents feeding discovery into spec and implementation planning](assets/zuggie-workflow.png)

## Default workflow

`/zuggie-spec` is the default entrypoint. It produces a decision-ready specification. After you review and accept/refine that spec, `/zuggie-impl` executes from the accepted spec using worktrees, milestones, engineers, and reviewers.

## What you get

- `/zuggie-spec` — Build a decision-ready implementation spec for a change.
- `/zuggie-impl` — Implement from an accepted spec using milestone-based execution in a dedicated worktree.
- `/zuggie-structured-debug` — Structured debugging workflow (WIP/experimental).
- Skill-local prompts for explorer, tech-lead, engineer, reviewer, and debugger roles.
- Skills spawn general subagents with the full role instructions and task context. The harness chooses models and reasoning settings.

Planning, implementation, review, and debug are intentionally separated into explicit roles so each stage has clear ownership and outputs.

## Prerequisites

- Claude Code and/or Codex CLI.
- RAC CLI — Node 20 or later required. Install/run via `npx github:raniejade/rac`. See https://github.com/raniejade/rac.

## Install

```bash
rac pack add zuggie github:raniejade/zuggie --ref <ref>
rac install --targets claude,codex --kind skill
```

Use ``--ref v<X.Y.Z>`` for a stable release (e.g. ``--ref v0.2.0``). See [Releases](https://github.com/raniejade/zuggie/releases) for available tags.

## Generated output locations

`rac install --targets claude,codex --kind skill` generates into standard vendor locations in the target project:

- Claude skills under `.claude/skills/`
- Codex skills under `.agents/skills/`

Role prompts and review checklists are bundled in the installed skills’
`references/` directories. Zuggie does not register custom agent types.

## Usage

```
/zuggie-spec add a cache invalidation policy for X
/zuggie-impl implement the accepted spec above
```

WIP/experimental debug path:

```
/zuggie-structured-debug Y fails when Z
```

## Validation

```bash
npx -y github:raniejade/rac#v0.3.0 doctor --targets claude,codex --kind skill
npx -y github:raniejade/rac#v0.3.0 install --targets claude,codex --kind skill --dry-run
```

CI runs these same checks on every PR and push to main.

## Contributing — changelog entries

Run `npx -y @changesets/cli@^2.27 add` and commit the resulting `.changeset/*.md` file alongside your change.
Include one for every PR that has a user-visible effect; omit it for pure docs or CI changes.

## Source of truth

- `.rac/config.toml`
- `.rac/skills/*/SKILL.tpl.md`
- `.rac/skills/*/references/*.md`

## License

MIT — see [LICENSE](LICENSE).
