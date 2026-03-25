import asyncio
import json
import os

from fastmcp import FastMCP

from agents import AGENT_CONFIGS, run_agent

mcp = FastMCP(name="zuggie-spawn")

_KNOWN_TYPES = set(AGENT_CONFIGS.keys())


def _resolve_plugin_root() -> str:
    """Return plugin root from env var or by walking up from this file."""
    env_val = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if env_val:
        return env_val
    # __file__ is plugins/zuggie/mcp/server.py — parent of mcp/ is plugin root
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


@mcp.tool()
async def spawn_agent(type: str, worktree: str, prompt: str) -> str:
    """Spawn a single agent using the claude CLI."""
    if type not in _KNOWN_TYPES:
        return f"Error: unknown agent type {type!r}. Known types: {sorted(_KNOWN_TYPES)}"
    if not os.path.isdir(worktree):
        return f"Error: worktree path does not exist or is not a directory: {worktree!r}"

    plugin_root = _resolve_plugin_root()
    return await run_agent(type, worktree, prompt, plugin_root)


@mcp.tool()
async def spawn_agents(agents: list[dict]) -> str:
    """Spawn multiple agents concurrently using the claude CLI.

    Each element of `agents` must have keys: type, worktree, prompt.
    Returns a JSON object mapping index (as string) to each agent's result.
    """
    plugin_root = _resolve_plugin_root()

    async def _run_one(index: int, spec: dict) -> tuple[int, str]:
        agent_type = spec.get("type", "")
        worktree = spec.get("worktree", "")
        prompt = spec.get("prompt", "")

        if agent_type not in _KNOWN_TYPES:
            return index, f"Error: unknown agent type {agent_type!r}. Known types: {sorted(_KNOWN_TYPES)}"
        if not os.path.isdir(worktree):
            return index, f"Error: worktree path does not exist or is not a directory: {worktree!r}"

        result = await run_agent(agent_type, worktree, prompt, plugin_root)
        return index, result

    tasks = [_run_one(i, spec) for i, spec in enumerate(agents)]
    pairs = await asyncio.gather(*tasks)
    return json.dumps({str(i): result for i, result in pairs})


if __name__ == "__main__":
    mcp.run(transport="stdio")
