from fastmcp import FastMCP

mcp = FastMCP(name="zuggie-spawn")


@mcp.tool()
def spawn_agent(type: str, worktree: str, prompt: str) -> str:
    """Spawn a single agent using the claude CLI."""
    return "stub: spawn_agent not yet implemented"


@mcp.tool()
def spawn_agents(agents: list[dict]) -> str:
    """Spawn multiple agents using the claude CLI."""
    return "stub: spawn_agents not yet implemented"


if __name__ == "__main__":
    mcp.run(transport="stdio")
