---
name: zuggie-structured-debug
description: >
  Structured debugging pipeline that creates a minimal reproducible example
  for a bug, regression, or crash. TRIGGER when: user asks to "debug with
  zuggie", "use zuggie-structured-debug", reports a bug, regression, or
  crash, or asks to reproduce a failing behavior.
version: 1.0.0
---

Run the structured debug pipeline: explore, reproduce, review, and optionally
hand off to the fix workflow.

Usage: /zuggie-structured-debug <bug description>

## Your role

You are the **orchestrator**. You coordinate the pipeline by spawning
agents (via the Agent tool) and managing git branches. You do NOT:
- Write or edit application code yourself
- Skip steps because you think you already know the answer
- Act as the debugger or reviewer — you delegate to them

Every step below that says "spawn" means: use the **Agent tool** with
the appropriate `subagent_type` (e.g. `zuggie:zuggie-debugger`).
Do not simulate the agent's work or summarise what you think it would
produce — actually spawn it.

When you need to understand the codebase (e.g. before spawning the
debugger), spawn **Explore** agents (`subagent_type: Explore`) rather
than using Glob, Grep, or Read yourself. Explore agents are fast and
cheap — use them freely for recon.

## Hard rules — no exceptions

- **NEVER merge anything into main or master.** All work happens on
  debug branches. The user merges to main themselves.
- **NEVER skip the Explore step.** You MUST spawn Explore agents to
  gather bug context before invoking the debugger. Without it the
  debugger is working blind.
- **NEVER write or edit code yourself.** All code changes go through
  the debugger agent.
- **NEVER accept a deferral of the reproduction task.** If the
  debugger's summary indicates the reproduction was skipped, deferred,
  or only partially done — treat it as a blocking issue. Re-spawn the
  debugger with the same bug brief and a note that the previous attempt
  was incomplete. Excuses like "this is complex" or "can be done in a
  follow-up" are not acceptable — the task was scoped specifically for
  the debugger.

## Bash rules

These apply to you (the orchestrator) and all agents you spawn.

- Do not chain Bash commands with `&&` or `;` — run each command as a
  separate Bash call so failures are visible. Piping output to another
  command (e.g. `cmd | grep`) is fine.

**You MUST include the following block verbatim in the prompt of every
agent you spawn** (debugger, reviewer — no exceptions):

> **Bash rules — follow these exactly:**
> - Do not chain Bash commands with `&&` or `;` — run each command as a
>   separate Bash call so failures are visible. Piping output to another
>   command (e.g. `cmd | grep`) is fine.
> - Do not prefix commands with `cd <path> &&` or `cd <path>;`. The
>   working directory persists between Bash calls. If you need to change
>   directory, run `cd` as its own separate Bash call.

## Progress tracking

Use `TaskCreate` and `TaskUpdate` to give the user real-time visibility
into the pipeline. Only the orchestrator calls these — agents do not.

Tasks are displayed in creation order, so create them just-in-time to
keep the list intuitive.

### Early pipeline tasks (create before Step 1)

Create these 4 tasks using `TaskCreate` at the very start:

1. **Set up workspace** — activeForm: `Setting up workspace`
2. **Understand the bug** — activeForm: `Gathering bug context`
3. **Reproduce the bug** — activeForm: `Creating minimal reproduction`
   — blockedBy: task 2
4. **Review reproduction** — activeForm: `Reviewing reproduction quality`
   — blockedBy: task 3

## Pipeline

### Step 1 — Worktree

Mark the Setup task as `in_progress`.

First, check whether you are already inside a separate worktree by
running:

    git rev-parse --show-toplevel

and comparing it with:

    git worktree list

If the current working directory is inside a **non-main worktree** (i.e.
not the bare repo or the primary working tree) and the branch is clean
(`git status` shows no uncommitted changes), then **skip worktree
creation** — just use the current worktree as-is.

Record these values:
- `BASE_BRANCH`: `main` (or `master` if that's the default branch)
- `DEBUG_BRANCH`: the current branch name

If you are on main or master (i.e. in the primary working tree), create
a worktree with a descriptive branch name derived from the bug
description (e.g. `debug/null-pointer-on-login`,
`debug/cache-key-collision`):

    git worktree add .zuggie/<branch-name> -b <branch-name>
    cd .zuggie/<branch-name>

Record these values:
- `BASE_BRANCH`: the branch you were on before creating the worktree
  (e.g. `main`)
- `DEBUG_BRANCH`: the new branch name (e.g. `debug/null-pointer-on-login`)

All subsequent steps run inside the worktree (whether reused or newly
created).

Mark the Setup task as `completed`.

### Step 1a — Understand the bug

Mark the Understand task as `in_progress`.

Before spawning the debugger, gather lightweight context so it starts
with a clear picture instead of exploring from scratch.

Spawn one or more **Explore** agents (`subagent_type: Explore`) with
targeted questions about the codebase:
- Find the code area the bug report references (files, functions,
  modules)
- Identify existing test patterns (test framework, test file locations,
  run command)
- Understand expected vs. reported behavior in code terms
- Find related existing tests as reference for style and conventions

Synthesize the exploration findings into a **Bug Brief** to pass to the
debugger:
- Bug description (verbatim from user input)
- Affected code area (files, functions, modules)
- Expected vs. actual behavior
- Existing test patterns (framework, conventions, run command)
- Related existing tests (as style reference)

**Do NOT explore the codebase yourself** (no Glob, Grep, or Read calls
to understand the code). Delegate to Explore agents instead.

Mark the Understand task as `completed`.

### Step 2 — Reproduce the bug

Mark the Reproduce task as `in_progress`.

Spawn `zuggie:zuggie-debugger` with:
- The Bug Brief from Step 1a
- The worktree path (absolute path to `.zuggie/<DEBUG_BRANCH>`)
- The branch name (`DEBUG_BRANCH`)
- The bash rules block (verbatim, as specified in the Bash rules section)

Wait for the debugger's Reproduction Summary. If the summary indicates
the reproduction was skipped, deferred, or only partially done — treat
it as a blocking issue and re-spawn the debugger. Include the previous
attempt's summary and a note that reproduction is non-negotiable.

If the debugger reports a genuine blocker (e.g. missing dependency,
broken environment) after systematic investigation, surface the findings
to the user and stop.

Mark the Reproduce task as `completed`.

### Step 3 — Review reproduction

Mark the Review task as `in_progress`.

Spawn `zuggie:zuggie-reviewer` with:
- The original bug description
- The Bug Brief from Step 1a
- The debugger's Reproduction Summary
- Output of `git diff <BASE_BRANCH>...HEAD` on the debug branch
- The worktree path so the reviewer reads files from the correct branch

The reviewer evaluates:
- Does it actually demonstrate the reported bug?
- Is it minimal (no unnecessary setup or code)?
- Is it self-contained?
- Does it follow project test conventions?

Triage the review verdict:
- **Blocking**: re-spawn `zuggie:zuggie-debugger` with the reviewer's
  specific feedback, the original Bug Brief, and the worktree details.
- **Minor/nit**: defer unless the fix is trivial.
- Only re-review if the reviewer's verdict was "request changes".

Mark the Review task as `completed`.

### Step 4 — Report + optional fix handoff

Present to the user:
- Reproduction file(s) and the exact command to run them
- What the reproduction demonstrates (expected vs. actual behavior)
- Key findings from the investigation (bug mechanism, affected area)
- Reviewer verdict

Then ask: **"Would you like to fix this bug using the zuggie workflow?"**

- If yes: invoke `/zuggie` with the bug description, the reproduction
  file path, and the investigation findings as context. The reproduction
  serves as both the spec and the verification test — the fix should
  make the failing test/harness pass.
- If no: done.
