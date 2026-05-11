---
"zuggie": minor
---

- `zuggie-spec`: output is now plain markdown for all vendors (Claude, Codex, OpenCode). Codex output no longer carries the `<proposed_plan>` XML wrapper; OpenCode output is no longer empty.
- `zuggie-reviewer`: output requires a severity tag per issue (`[blocking]` or `[minor]`). Orchestrators now re-spawn on any `[blocking]` line regardless of verdict, with a verdict-only fallback when tags are absent.
- `zuggie-explorer`: new read-only recon agent shipped in the pack. Available after `rac install` on Claude (`haiku`), Codex (`gpt-5.4-mini`), and OpenCode. Skills now name it explicitly.
- `zuggie-structured-debug`: Observation Brief has a defined schema written to `.zuggie/<DEBUG_BRANCH>-observations.md`. Step 7 prints a concrete `Suggested fix command: /zuggie-impl fix …` rather than asking the user.
- `zuggie-tech-lead`: exploration milestones now use a `[explore] <question>` title prefix; the orchestrator dispatches them to `zuggie-explorer` instead of `zuggie-engineer`.
- CI: pinned `rac` CLI to `v0.3.0` in `validate.yml`; added a `changeset-gate` job that fails PRs touching `.rac/**` without a changeset; removed the dead `0.0.0` skip guard in `publish.yml`.
