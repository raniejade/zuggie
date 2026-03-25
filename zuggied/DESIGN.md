# zuggied: Design Document

## Decisions
- **Language**: Python (Claude Agent SDK, asyncio, Textual for TUI)
- **Repo**: Same repo, standalone tool lives in `zuggied/` subfolder. Existing plugin stays at `plugins/zuggie/`.
- **Frontend**: TUI first (Textual)

## Problem Statement

The current zuggie Claude Code plugin has two fundamental limitations:
1. **Worktree isolation is instruction-based only** — agents are *told* not to write outside their worktree, but nothing enforces it at runtime
2. **No external event handling** — the plugin cannot listen for GitHub PRs, webhooks, or any external triggers

These are inherent to the Claude Code plugin model. To solve them, we need a standalone daemon that manages agent sessions, enforces isolation at the runtime level, and can react to external events.

---

## Architecture Overview

```
+-------------------+       Unix Socket        +-------------------+
|   Frontend        | <======================> |   Daemon          |
|   (TUI / Webapp)  |   JSON-RPC over ndjson   |   (zuggied)       |
+-------------------+                          +--------+----------+
                                                        |
                                    +-------------------+-------------------+
                                    |                                       |
                           +--------+----------+               +-----------+---------+
                           |  Agent Runtime    |               |  Event Sources      |
                           |  (Claude SDK)     |               |  (future)           |
                           +-------------------+               +---------------------+
```

**Per-project daemon model:** One daemon instance per project directory. All state lives in `<project>/.zuggie/`. To work on multiple projects, run multiple daemons — each binds its own socket at `<project>/.zuggie/zuggie.sock`.

**Three components:**
- **zuggied** — per-project, long-running daemon. Manages sessions, agents, worktrees. Single process, async.
- **Frontend** — TUI or webapp. Connects to a daemon over its unix socket. Stateless display layer. Multiple frontends can connect simultaneously.
- **Agent sessions** — Claude SDK invocations managed as async tasks within the daemon.

The daemon is the primary artifact. The frontend is a consumer. See [SPEC.md](SPEC.md) for the complete daemon specification.

---

## Key Design Decisions

1. **Orchestrator is an LLM agent, not code.** It uses skills/tools to drive the workflow. This preserves the flexibility of the current plugin — the agent can adapt, skip steps, handle edge cases, and make judgment calls that rigid code cannot.

2. **Infrastructure is code, not instructions.** Worktree isolation, git safety, event handling — these are enforced by the daemon runtime via hooks and tool restrictions. The agent doesn't need to "remember" not to write outside its worktree.

3. **Skills as MCP tools.** The orchestrator's capabilities are defined as tools. Adding a new capability (e.g., "run tests", "deploy preview") is just adding a new tool — the orchestrator can immediately reason about when to use it.

4. **Unix socket + JSON-RPC.** Simple, well-understood protocol. Any frontend (TUI, webapp, CLI script, IDE plugin) can connect. No HTTP overhead for local communication.

5. **SQLite for state.** Single-file database, no external dependencies, good enough for local daemon use. Session state survives daemon restarts.

6. **Personal tool, not a platform.** No multi-user model, no auth on the socket, no horizontal scaling. This is opinionated tooling for orchestrating parallel agent work with isolation — replacing the "multiple Claude Code tabs with worktrees" workflow.

7. **One daemon per project.** Each project gets its own daemon instance with its own socket, database, and configuration. No global registry of projects. This keeps the daemon simple (no multi-project state) and maps naturally to how you work — cd into a project and start working.

---

## Open Questions

1. **Orchestrator prompt design** — How much of the current SKILL.md should be ported vs. letting the agent discover the workflow through available tools? A minimal prompt with good tool descriptions might be sufficient.

2. **Session interaction** — Should the user be able to "chat" with a running session (provide feedback, redirect the orchestrator mid-flight)? The protocol supports it (`session.send_message`), but the UX needs thought.

3. **Multi-project sessions** — Could a session span multiple registered projects? (e.g., update a library and its consumers). Not needed now, but worth considering in the data model.
