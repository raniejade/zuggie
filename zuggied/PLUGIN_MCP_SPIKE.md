# Plugin MCP Spike: Spawn Tool via MCP Server

## Problem

The current zuggie plugin uses Claude Code's built-in `Agent` tool to spawn sub-agents. This means:
- The orchestrator (SKILL.md) controls agent spawning, but can't set `cwd` or sandbox config on the spawned agents
- Agents are told via instructions to `cd` into their worktree — not enforced
- No way to inject MCP tools (like `git_commit`) into spawned agents

## Idea

Create an MCP server that exposes a `spawn_agent` tool. The plugin's orchestrator calls this tool instead of the built-in `Agent` tool. The MCP server process handles the actual agent spawning via the Agent SDK, giving us control over `cwd`, sandbox, and tool configuration.

## How It Works

```
Claude Code (orchestrator)
  |
  |-- calls MCP tool: spawn_agent(type="engineer", worktree="...", prompt="...")
  |
  v
MCP Server (Python process, long-running)
  |
  |-- creates new query() call with:
  |     cwd = worktree path
  |     sandbox = { enabled: true }
  |     disallowed_tools = [Agent, ...]
  |     mcp_servers = [git_tools_server]
  |
  |-- awaits completion
  |-- returns summary to orchestrator
```

## MCP Server Implementation

A lightweight Python MCP server that:
1. Exposes `spawn_agent` and `spawn_agents` tools
2. On tool call, runs a new Agent SDK `query()` with proper isolation
3. Returns the agent's summary as the tool result

```python
from mcp.server import Server
from claude_agent_sdk import query, ClaudeAgentOptions

server = Server("zuggie-spawn")

AGENT_CONFIGS = {
    "engineer": {
        "model": "sonnet",
        "disallowed_tools": ["Agent"],
        "system_prompt": "...",  # from zuggie-engineer.md
    },
    "tech_lead": {
        "model": "opus",
        "disallowed_tools": ["Write", "Edit", "Agent"],
        "system_prompt": "...",  # from zuggie-tech-lead.md
    },
    "reviewer": {
        "model": "opus",
        "disallowed_tools": ["Write", "Edit", "Bash", "Agent"],
        "system_prompt": "...",  # from zuggie-reviewer.md
    },
}

@server.tool()
async def spawn_agent(type: str, worktree: str, prompt: str) -> str:
    config = AGENT_CONFIGS[type]

    result = []
    async for message in query(
        prompt=prompt,
        options=ClaudeAgentOptions(
            model=config["model"],
            system_prompt=config["system_prompt"],
            cwd=worktree,
            sandbox={
                "enabled": True,
                "autoAllowBashIfSandboxed": True,
            },
            disallowed_tools=config["disallowed_tools"],
        )
    ):
        if message.type == "assistant":
            result.append(message.content)

    return "\n".join(result)
```

## Plugin Changes

SKILL.md would change from:
```
Spawn zuggie:zuggie-engineer via the Agent tool
```
to:
```
Call the spawn_agent MCP tool with type="engineer"
```

The `Agent` tool would be disallowed for the orchestrator — all spawning goes through the MCP server.

## What This Buys Us (Over Current Plugin)

| Feature | Current plugin | With MCP spawn server |
|---------|---------------|----------------------|
| `cwd` enforcement | Instructions only | SDK `cwd` parameter |
| Filesystem sandbox | None | OS-level via SDK sandbox |
| Tool restrictions | Instructions only | `disallowed_tools` (hard block) |
| Git command control | Instructions only | Future: block `git` in Bash, expose MCP git tools |
| Agent spawning | Built-in `Agent` tool | Custom `query()` with full control |

## Limitations

- The MCP server runs as a separate process — needs to be started alongside Claude Code
- The orchestrator still runs inside Claude Code without sandbox (it's the SKILL.md skill)
- Communication overhead: MCP tool call → MCP server → Agent SDK → back
- The orchestrator can't stream sub-agent output to the user in real-time (MCP tools return a single result)

## Relationship to zuggied

This is a stepping stone. The full daemon (zuggied) does the same thing but also manages:
- Session lifecycle and persistence
- Worktree creation/cleanup
- Multiple frontends
- Event-driven session creation

The MCP spawn server could serve as a prototype for the daemon's agent runtime, and could be used immediately to improve the current plugin's isolation.
