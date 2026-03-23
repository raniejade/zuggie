---
name: zuggie-implement
description: >
  Full planning, implementation, and review pipeline using zuggie agents.
  TRIGGER when: user asks to "implement using zuggie", "use zuggie",
  "implement with zuggie", or references the zuggie workflow for
  implementing a task.
version: 1.0.0
---

Run `/zuggie:implement` with the task description provided by the user.

This skill exists to ensure the full pipeline (worktree, plan, implement,
review, triage, report) is followed. Do not invoke zuggie agents directly —
always go through the `/zuggie:implement` command.
