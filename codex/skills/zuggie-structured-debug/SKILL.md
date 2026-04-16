---
name: zuggie-structured-debug
description: >
  Structured debugging workflow using zuggie's dedicated debugger and
  reviewer subagents. Trigger for bug reproduction, regressions, and
  failing behavior investigation.
---

Run the structured debug workflow using the installed Codex subagents.

## Required subagents

Use these installed custom subagents by name:
- `zuggie-debugger`
- `zuggie-reviewer`

## Workflow

1. Create or reuse a clean `.zuggie/<branch>` debug worktree.
2. Gather observed facts first.
3. Spawn `zuggie-debugger` to reproduce and explain the bug.
4. Require a hypothesis ledger, minimized reproduction, and causal
   mechanism.
5. Spawn `zuggie-reviewer` to review the reproduction output.
6. Report the reproduction branch, run command, and bug mechanism.

## Rules

- Do not turn the debug workflow into a fix workflow unless the user
  explicitly asks for that next.
- Keep observations factual before the debugger starts theorizing.
