# Shiplight Cursor Plugins

AI-powered test automation for Cursor — browser testing via MCP and cloud test management.

## Plugins

### mcp-plugin (free)

Browser automation MCP tools + UI verification skill.

- **MCP tools** — live browser sessions, navigation, actions, page inspection, debugging
- **Skill** — `/verify` — verify UI changes in the browser using MCP tools

### cloud-plugin (paid)

Cloud test case management via REST API.

- **Skill** — `/shiplight` — create, run, and manage test cases, environments, folders, and accounts via Shiplight API

## Install

### From Marketplace

In Cursor chat, run:

```
/add-plugin ShiplightAI/cursor-plugin mcp-plugin
```

```
/add-plugin ShiplightAI/cursor-plugin cloud-plugin
```

After installation, restart Cursor for the plugins to take effect.

### Manual Install

```bash
git clone https://github.com/ShiplightAI/cursor-plugin.git
cd cursor-plugin
bash install.sh                                        # Install mcp-plugin globally (~/.cursor)
bash install.sh --all                                  # Install all plugins globally
bash install.sh --target ~/my-project                  # Install to a specific project
```

Restart Cursor after setup.

### Verify with Cursor Agent CLI

```bash
# Check MCP server is detected (mcp-plugin)
cursor agent mcp list

# Enable and approve the server
cursor agent mcp enable shiplight

# List available tools
cursor agent mcp list-tools shiplight

# Test a browser session
cursor agent --print --approve-mcps \
  "Open a browser session at https://example.com, get the DOM, take a screenshot, then close the session"
```

## Verify

After installing, go to **Cursor Settings** (Cmd+Shift+J) → **MCP** to confirm the Shiplight MCP server is registered (mcp-plugin). Skills `/verify` and `/shiplight` should be available in Cursor chat.

## Links

- [Shiplight](https://shiplight.ai)
- [Documentation](https://docs.shiplight.ai)
