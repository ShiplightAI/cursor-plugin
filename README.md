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

### Local Install (for development/testing)

To test the plugins locally before publishing, copy the plugin components into your project's `.cursor/` directory.

```bash
# Clone the repo
git clone https://github.com/ShiplightAI/cursor-plugin.git
cd cursor-plugin

TARGET=/path/to/your-project
```

**mcp-plugin** — MCP server + `/verify` skill:

```bash
# Copy MCP config (creates .cursor/mcp.json with browser server)
mkdir -p $TARGET/.cursor
cp plugins/mcp-plugin/.mcp.json $TARGET/.cursor/mcp.json

# Copy skill
mkdir -p $TARGET/.cursor/plugins/shiplight-mcp/skills/verify
cp plugins/mcp-plugin/skills/verify/SKILL.md \
   $TARGET/.cursor/plugins/shiplight-mcp/skills/verify/SKILL.md
```

**cloud-plugin** — `/shiplight` skill:

```bash
# Copy skill
mkdir -p $TARGET/.cursor/plugins/shiplight-cloud/skills/shiplight
cp plugins/cloud-plugin/skills/shiplight/SKILL.md \
   $TARGET/.cursor/plugins/shiplight-cloud/skills/shiplight/SKILL.md
```

Restart Cursor after setup.

### Verify with Cursor Agent CLI

```bash
# Check MCP server is detected (mcp-plugin)
cursor agent mcp list

# Enable and approve the server
cursor agent mcp enable browser

# List available tools
cursor agent mcp list-tools browser

# Test a browser session
cursor agent --print --approve-mcps \
  "Open a browser session at https://example.com, get the DOM, take a screenshot, then close the session"
```

## Verify

After installing, go to **Cursor Settings** (Cmd+Shift+J) → **MCP** to confirm the Shiplight browser MCP server is registered (mcp-plugin). Skills `/verify` and `/shiplight` should be available in Cursor chat.

## Links

- [Shiplight](https://shiplight.ai)
- [Documentation](https://docs.shiplight.ai)
