# Shiplight Cursor Plugins

AI-powered test automation for Cursor — browser testing via MCP and cloud test management.

## Plugins

### mcp-plugin (free)

Browser automation MCP tools + UI verification skill.

- **MCP tools** — live browser sessions, navigation, actions, page inspection, debugging
- **Skill** — `/verify` — verify UI changes in the browser using MCP tools

### cloud-plugin (paid)

Cloud test case management via REST API.

- **Skill** — `/shiplight` — create, run, and manage test cases, environments, folders, and accounts

## Install

```bash
# Add the marketplace (one-time)
/plugin marketplace add ShiplightAI/cursor-plugin

# Install the free plugin (browser MCP tools + verify skill)
/plugin install mcp-plugin@shiplight-plugins

# Install the cloud plugin (requires API token)
/plugin install cloud-plugin@shiplight-plugins
```

After installation, restart Cursor for the plugins to take effect.

## Verify

After installing, go to **Cursor Settings > MCP** to confirm the Shiplight MCP servers are registered.

## Links

- [Shiplight](https://shiplight.ai)
- [Documentation](https://docs.shiplight.ai)
