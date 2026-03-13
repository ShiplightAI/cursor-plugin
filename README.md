# Shiplight Cursor Plugin

AI-powered test automation for Cursor — browser testing, YAML test authoring, and cloud test management.

## Features

- **MCP tools** — live browser sessions, navigation, actions, page inspection, debugging, and cloud sync
- **Skills:**
  - `/verify` — verify UI changes in the browser using MCP tools
  - `/create_tests` — scaffold a local test project, configure credentials, and write YAML tests by walking through the app in a browser
  - `/cloud` — sync test cases, templates, and functions with Shiplight cloud

Cloud tools (`save_test_case`, `get_test_case`, etc.) are automatically available when `SHIPLIGHT_API_TOKEN` is set in the project's `.env` file.

## Install

### From Marketplace

In Cursor chat, run:

```
/add-plugin ShiplightAI/cursor-plugin mcp-plugin
```

After installation, restart Cursor for the plugin to take effect.

### Manual Install

```bash
git clone https://github.com/ShiplightAI/cursor-plugin.git
cd cursor-plugin
bash install.sh                                        # Install to current directory
bash install.sh --user                                 # Install to user-level (~/.cursor)
bash install.sh --project ~/my-project                  # Install to a specific project
```

Restart Cursor after setup.

## Verify

After installing, go to **Cursor Settings** (Cmd+Shift+J) → **MCP** to confirm the Shiplight MCP server is registered. Skills `/verify`, `/create_tests`, and `/cloud` should be available in Cursor chat.

## Links

- [Shiplight](https://shiplight.ai)
- [Documentation](https://docs.shiplight.ai)
