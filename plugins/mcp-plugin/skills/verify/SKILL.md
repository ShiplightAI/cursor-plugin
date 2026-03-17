---
name: verify
description: "Verify UI changes in the browser using Shiplight MCP tools."
---

# Verify UI Changes

Use the Shiplight MCP browser tools to visually verify that your code changes look and behave correctly in a real browser.

## When to use

Use `/verify` after making UI changes to confirm they render correctly. This is useful for:
- Checking layout, styling, or component changes visually
- Verifying interactive behavior (clicks, form inputs, navigation)
- Pre-commit sanity checks on UI work
- Debugging visual regressions

## Steps

### 0. Check API keys

Before starting, check that the user has at least one LLM API key (`ANTHROPIC_API_KEY` or `GOOGLE_API_KEY`) — these are required for browser actions. If not available, ask:

> To verify UI changes, I need an Anthropic or Google API key. Do you have one?

If provided, append it to the project's `.env` file (create if needed) and tell them: "Saved to `<project>/.env` — make sure `.env` is in your `.gitignore`." The MCP server must be reconnected (`/mcp`) for the new key to take effect.

If the key is already working (e.g. `act` succeeds), skip this step.

The following steps are a general guideline — adapt based on what makes sense for the specific changes:

1. **Understand what changed** — this is the most important step as it determines your test coverage. Analyze the code changes and build a verification plan targeting the key areas, balancing thoroughness with cost.

2. **Start the dev server** (if not already running) — check if the app's dev server is running. If not, start it in the background using the appropriate command (e.g. `npm run dev`, `yarn dev`). Wait a few seconds for it to be ready.

3. **Open a browser session** — call `new_session` with the `starting_url` pointing to the page you want to verify.

4. **Navigate to the relevant page** — if the change is on a specific route, use `navigate` or pass the full URL in `new_session`.

5. **Inspect the page** — call `inspect_page` to get the DOM tree with element indices and a screenshot. **Always read the DOM file first** — it provides the element indices needed for `act` and consumes far fewer tokens. Only view the screenshot when you specifically need visual information (layout, colors, images), as screenshots consume significantly more tokens than DOM.

6. **Interact and verify** — use `act` to simulate user actions based on the element indices from `inspect_page`.

7. **Check for errors** — call `get_browser_console_logs` to check for any JavaScript errors that may have been introduced.

8. **Report findings** — summarize what you verified:
   - What pages/components were checked
   - Whether the UI renders correctly
   - Any console errors or visual issues found
   - Screenshots showing the verified state

9. **Close the session** — call `close_session` when done. It returns `local_video_path` and `local_trace_path`.

10. **Generate the local report** — if the session was started with `record_evidence: true`, call `generate_html_report` with the local paths so the report works immediately on disk:

    ```json
    {
      "session_id": "<session_id>",
      "local_video_path": "<local_video_path from close_session>",
      "local_trace_path": "<local_trace_path from close_session>",
      "title": "...",
      "summary": "...",
      "checks": [...]
    }
    ```

    Show the returned `file_path` to the user so they can open and review it.

11. **Upload the report for sharing** — when the user wants a shareable link (e.g. to attach to a PR), and `SHIPLIGHT_API_TOKEN` is available:

    ```bash
    # Get presigned upload URLs for all three files in one call
    URLS=$(curl -s -X POST \
      -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "video_filename": "<basename of local_video_path>",
        "trace_filename": "<basename of local_trace_path>",
        "report_filename": "report.html"
      }' \
      https://api.shiplight.ai/v1/agent/report-upload-urls)
    # → { video: { uploadUrl, url }, trace: { uploadUrl, url }, report: { uploadUrl, url } }

    # Upload video and trace in parallel
    curl -s -X PUT -H "Content-Type: video/webm" --upload-file "$LOCAL_VIDEO_PATH" "$VIDEO_UPLOAD_URL" &
    curl -s -X PUT -H "Content-Type: application/zip" --upload-file "$LOCAL_TRACE_PATH" "$TRACE_UPLOAD_URL" &
    wait

    # Patch the local HTML with cloud URLs (no need to regenerate)
    python3 - <<'EOF'
    import sys, re, urllib.parse

    report_path, video_url, trace_url = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(report_path) as f:
        html = f.read()
    html = re.sub(r'src="file://[^"]*\.webm"', f'src="{video_url}"', html)
    trace_encoded = urllib.parse.quote(trace_url, safe='')
    html = html.replace(
        '<p class="no-trace">Trace will be available after uploading.</p>',
        f'<a class="trace-btn" href="https://trace.playwright.dev/?trace={trace_encoded}" target="_blank" rel="noopener noreferrer">Open Trace Viewer →</a>'
    )
    with open(report_path, 'w') as f:
        f.write(html)
    EOF
    "$REPORT_FILE_PATH" "$VIDEO_URL" "$TRACE_URL"

    # Upload the patched HTML
    curl -s -X PUT -H "Content-Type: text/html" --upload-file "$REPORT_FILE_PATH" "$REPORT_UPLOAD_URL"
    ```

    Return the `report.url` from the first curl as the permanent shareable link.

## Apps that require login

If the app requires authentication, log in once and save the session so future sessions skip the login step:

1. Open a browser session with `new_session` at the app's login page.
2. Ask the user to switch to the browser and log in manually. Wait for them to confirm.
3. Call `save_storage_state` to save cookies and localStorage to `~/.shiplight/<site_url>/storage-state.json` (e.g. `~/.shiplight/http_localhost_3000/storage-state.json`).
4. For all future sessions, pass the same path as `storage_state_path` to `new_session` to restore the authenticated state instantly.

If a saved storage state file already exists, use it automatically when creating new sessions.

## Tips

- Use `inspect_page` to understand page state. **Always read the DOM file first** — screenshots consume significantly more tokens. Only view the screenshot when you need visual info.
- Use `verify` actions inside `act` to assert expected UI state (e.g. text is visible, element exists).
- If a page takes time to load, use a `wait` action or `wait_for_page_ready` before taking a screenshot.
- Use `get_browser_console_logs` to catch runtime errors that aren't visible in the UI.
- You can open multiple sessions to compare different pages or states side by side.
