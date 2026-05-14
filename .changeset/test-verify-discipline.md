---
"zuggie": minor
---

`zuggie-engineer` now requires structured test evidence in the `Tests:` return block — verbatim command(s), outcome, and the new or modified test's path and intent. Bug-fix milestones must follow the Prove-It pattern and attest failing-before, passing-after. Non-behavioral milestones may declare exemption with a one-line reason.

`zuggie-reviewer` adopts a five-axis review (Correctness, Readability & simplicity, Architecture, Security, Performance). Missing test evidence for new behavior or a bug fix is now `[blocking]`. Security regressions on touched trust boundaries are `[blocking]`. The reviewer reads optional reference checklists when paths are provided by the caller.

New reference assets `testing-patterns.md` and `security-checklist.md` ship under the `zuggie-impl` skill directory and install alongside it. The `zuggie-impl` orchestrator passes both paths to `zuggie-reviewer` at every review spawn. The `zuggie-structured-debug` orchestrator passes `testing-patterns.md` only to the reproduction reviewer.
