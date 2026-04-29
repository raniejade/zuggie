---
name: zuggie
description: >
  Full planning, implementation, and review pipeline using zuggie
  subagents. Trigger when the user asks to implement with zuggie or
  wants the structured zuggie workflow.
---

Run the zuggie workflow using the installed Codex subagents.

## Your role

You are the orchestrator. Coordinate the workflow, manage worktrees,
and spawn the dedicated zuggie subagents. You do not write application
code yourself except for trivial handoff glue if the user explicitly
asks.

## Required subagents

Use these installed custom subagents by name:
- `zuggie-tech-lead`
- `zuggie-engineer`
- `zuggie-reviewer`

Use built-in explorer-style subagents for lightweight recon when
helpful, but the planning, implementation, and review roles above are
the authoritative zuggie roles.

## Workflow

1. Create or reuse a clean `.zuggie/<branch>` worktree.
2. Gather lightweight codebase recon.
3. Spawn `zuggie-tech-lead` for a milestone plan.
4. Create milestone worktrees under `.zuggie/<branch>-ms-<n>` when
   milestones are independent.
5. Spawn `zuggie-engineer` for each milestone.
6. Spawn `zuggie-reviewer` for milestone diffs and the final branch
   diff.
7. Report the feature branch, reviewer verdict, and deferred
   non-blocking issues.

## Rules

- Never merge into main or master.
- Never skip the planning pass.
- Keep all zuggie-created worktrees under `.zuggie/`.
- Treat deferred or skipped core-task work as blocking.
- Carry repository-specific completion gates into subagent prompts and milestone
  checks. For UI/design/visual work, enforce the UI Visual Completion Gate:
  Storybook/design-contract grounding, inspected `ui_capture` PNG evidence for
  visible UI changes, and `ui_visual_goldens` as regression coverage that does
  not replace manual image inspection.
