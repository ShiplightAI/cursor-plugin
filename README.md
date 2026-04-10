# Shiplight Cursor Plugin

AI-powered test automation for Cursor — ship with confidence by letting the agent verify, test, and iterate autonomously.

## Features

- **MCP tools** — gives Cursor a real browser so it can autonomously code, verify in the browser, and iterate — closing the loop without human intervention
- **Skills** — commands that cover the full test lifecycle and code review:
  - `/verify` — visually confirm UI changes in the browser after a code change
  - `/create_e2e_tests` — generate e2e regression tests from code changes or app exploration
  - `/triage` — reproduce failing E2E tests, diagnose root causes, fix YAML tests, and report application bugs
  - `/cloud` — sync and share regression tests on the cloud platform for scheduled runs, team collaboration, and CI integration
  - `/review` — general code review covering correctness, readability, and maintainability
  - `/design-review` — review architecture and design patterns
  - `/security-review` — review for security vulnerabilities and best practices
  - `/privacy-review` — review for privacy concerns and data handling
  - `/compliance-review` — review for regulatory and compliance requirements
  - `/resilience-review` — review for fault tolerance and error handling
  - `/performance-review` — review for performance bottlenecks and optimization
  - `/seo-review` — review for SEO best practices
  - `/geo-review` — review for internationalization and localization

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

Go to **Cursor Settings** (Cmd+Shift+J) → **MCP** to confirm the Shiplight MCP server is registered. Skills `/verify`, `/create_e2e_tests`, `/triage`, `/cloud`, and the review skills should be available in Cursor chat.

## Links

- [Shiplight](https://shiplight.ai)
- [Documentation](https://docs.shiplight.ai)
