# zuggie

## 0.2.0

### Minor Changes

- ec6166d: `zuggie-engineer` now requires structured test evidence in the `Tests:` return block — verbatim command(s), outcome, and the new or modified test's path and intent. Bug-fix milestones must follow the Prove-It pattern and attest failing-before, passing-after. Non-behavioral milestones may declare exemption with a one-line reason.

  `zuggie-reviewer` adopts a five-axis review (Correctness, Readability & simplicity, Architecture, Security, Performance). Missing test evidence for new behavior or a bug fix is now `[blocking]`. Security regressions on touched trust boundaries are `[blocking]`. The reviewer reads optional reference checklists when paths are provided by the caller.

  New reference assets `testing-patterns.md` and `security-checklist.md` ship under the `zuggie-impl` skill directory and install alongside it. The `zuggie-impl` orchestrator passes both paths to `zuggie-reviewer` at every review spawn. The `zuggie-structured-debug` orchestrator passes `testing-patterns.md` only to the reproduction reviewer.

## 0.1.0

### Minor Changes

- 1160ed8: - `zuggie-spec`: output is now plain markdown for all vendors (Claude, Codex, OpenCode); Codex output no longer carries the `<proposed_plan>` XML wrapper, OpenCode output is no longer empty. Output schema expanded to require `## Context`, `## Non-goals`, and `## Risks / Tradeoffs` sections. Initial-spec behavior now prescribes pre-question inspection of `CLAUDE.md`, recent commits, the README, and named files before asking the user anything.
  - `zuggie-reviewer`: output requires a severity tag per issue (`[blocking]` or `[minor]`). Orchestrators now re-spawn on any `[blocking]` line regardless of verdict, with a verdict-only fallback when tags are absent.
  - `zuggie-explorer`: new read-only recon agent shipped in the pack. Available after `rac install` on Claude (`haiku`), Codex (`gpt-5.4-mini`), and OpenCode. Skills now name it explicitly.
  - `zuggie-structured-debug`: Observation Brief has a defined schema written to `.zuggie/<DEBUG_BRANCH>-observations.md`. Step 7 prints a concrete `Suggested fix command: /zuggie-impl fix …` rather than asking the user.
  - `zuggie-tech-lead`: exploration milestones now use a `[explore] <question>` title prefix; the orchestrator dispatches them to `zuggie-explorer` instead of `zuggie-engineer`.
  - CI: pinned `rac` CLI to `v0.3.0` in `validate.yml`; added a `changeset-gate` job that fails PRs touching `.rac/**` without a changeset; removed the dead `0.0.0` skip guard in `publish.yml`.

## 0.0.1

### Patch Changes

- e67aac8: Initial release.
