# Shiplight Cursor Plugin (deprecated)

> **This repo is deprecated.** Skills and MCP installation have moved to [ShiplightAI/agent-skills](https://github.com/ShiplightAI/agent-skills), which supports Cursor and 40+ other coding agents from a single source.

## Migrate

Install skills and the MCP server in one step:

```bash
npx -y skills add ShiplightAI/agent-skills -a cursor -y && \
npx -y add-mcp "npx -y @shiplightai/mcp@latest" -n shiplight --env PWDEBUG=console -a cursor -y
```

Cursor disables newly-added MCP servers by default. Enable it: **Cursor → Settings… → Cursor Settings → Tools & MCPs → Installed MCP Servers → shiplight (Disabled)** — toggle the switch to enable. Restart Cursor.

Full install guide: [docs.shiplight.ai quick start](https://docs.shiplight.ai/getting-started/quick-start).

## Why this moved

The Claude Code / Cursor / Codex plugin repos have been consolidated into a single source of truth. The [`skills`](https://www.npmjs.com/package/skills) CLI installs skills across 40+ agents; [`add-mcp`](https://www.npmjs.com/package/add-mcp) installs the MCP server. One update reaches every supported agent.

## Existing installs

The old `bash install.sh` flow still works, but it won't receive new skills or fixes. Re-install with the commands above to stay current.

## Links

- [Shiplight](https://shiplight.ai)
- [Documentation](https://docs.shiplight.ai)
- [New skills repo](https://github.com/ShiplightAI/agent-skills)
