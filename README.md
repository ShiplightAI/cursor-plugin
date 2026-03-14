# Shiplight Cursor Plugin

AI-powered test automation for Cursor — ship with confidence by letting the agent verify, test, and iterate autonomously.

## Features

- **MCP tools** — gives Cursor a real browser so it can autonomously code, verify in the browser, and iterate — closing the loop without human intervention
- **Skills** — three commands that cover the full test lifecycle:
  - `/verify` — visually confirm UI changes in the browser after a code change
  - `/create_tests` — generate e2e regression tests from code changes or app exploration
  - `/cloud` — sync and share regression tests on the cloud platform for scheduled runs, team collaboration, and CI integration

## Install

```bash
git clone https://github.com/ShiplightAI/cursor-plugin.git
cd cursor-plugin
bash install.sh                                        # Install to current directory
bash install.sh --user                                 # Install to user-level (~/.cursor)
bash install.sh --project ~/my-project                  # Install to a specific project
```

Restart Cursor after setup.

## Verify Installation

Go to **Cursor Settings** (Cmd+Shift+J) → **MCP** to confirm the Shiplight MCP server is registered. Skills `/verify`, `/create_tests`, and `/cloud` should be available in Cursor chat.

## Links

- [Shiplight](https://shiplight.ai)
- [Documentation](https://docs.shiplight.ai)
