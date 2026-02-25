---
name: verify
description: "Verify UI changes in the browser using Shiplight MCP tools."
---

# Verify UI Changes

Use the `@shiplightai/mcp` browser tools to visually verify that your code changes look and behave correctly in a real browser.

## When to use

Use `/verify` after making UI changes to confirm they render correctly. This is useful for:
- Checking layout, styling, or component changes visually
- Verifying interactive behavior (clicks, form inputs, navigation)
- Pre-commit sanity checks on UI work
- Debugging visual regressions

## Steps

Use the MCP tools from `@shiplightai/mcp`. The following steps are a general guideline — adapt based on what makes sense for the specific changes:

1. **Understand what changed** — this is the most important step as it determines your test coverage. Analyze the code changes and build a verification plan targeting the key areas, balancing thoroughness with cost.

2. **Start the dev server** (if not already running) — check if the app's dev server is running. If not, start it in the background using the appropriate command (e.g. `npm run dev`, `yarn dev`). Wait a few seconds for it to be ready.

3. **Open a browser session** — call `new_session` with the `starting_url` pointing to the page you want to verify.

4. **Navigate to the relevant page** — if the change is on a specific route, use `navigate` or pass the full URL in `new_session`.

5. **Inspect the page** — call `get_dom` to get the DOM tree with element indices. This tells you what's on the page and provides the element indices needed for `act`. If you need visual information (layout, colors, images), call `take_screenshot` with the `dom_state_id` from `get_dom`.

6. **Interact and verify** — use `act` to simulate user actions based on the element indices from `get_dom`.

7. **Check for errors** — call `get_browser_console_logs` to check for any JavaScript errors that may have been introduced.

8. **Report findings** — summarize what you verified:
   - What pages/components were checked
   - Whether the UI renders correctly
   - Any console errors or visual issues found
   - Screenshots showing the verified state

9. **Close the session** — call `close_session` when done.

## Apps that require login

If the app requires authentication, log in once and save the session so future sessions skip the login step:

1. Open a browser session with `new_session` at the app's login page.
2. Ask the user to switch to the browser and log in manually. Wait for them to confirm.
3. Call `save_storage_state` to save cookies and localStorage to `~/.shiplight/<site_url>/storage-state.json` (e.g. `~/.shiplight/http_localhost_3000/storage-state.json`).
4. For all future sessions, pass the same path as `storage_state_path` to `new_session` to restore the authenticated state instantly.

If a saved storage state file already exists, use it automatically when creating new sessions.

## Tips

- Use `get_dom` as the default way to understand page state. Only call `take_screenshot` when you need visual information (layout, colors, images).
- Use `verify` actions inside `act` to assert expected UI state (e.g. text is visible, element exists).
- If a page takes time to load, use a `wait` action or `wait_for_page_ready` before taking a screenshot.
- Use `get_browser_console_logs` to catch runtime errors that aren't visible in the UI.
- You can open multiple sessions to compare different pages or states side by side.
