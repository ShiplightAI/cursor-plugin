---
name: triage
description: "Triage failing E2E tests: reproduce failures, diagnose root causes, fix test issues in YAML, and report application bugs — with batch healing and concurrent browser investigation."
---

# Triage Failing Tests

Reproduce, diagnose, and fix failing Shiplight YAML tests. When tests break — due to UI changes, stale locators, changed flows, or assertion drift — triage systematically identifies what went wrong and fixes the tests. When the application itself is broken, triage reports the bug without modifying tests.

## When to use

Use `/shiplight:triage` when:
- A test run comes back red and you need to fix the test suite
- After a deployment changed the UI and tests haven't caught up
- In CI pipelines to auto-fix flaky or broken tests before they block merges
- After a batch of UI changes that likely broke multiple tests

## When NOT to use

Skip `/shiplight:triage` when:
- You need to create new tests from scratch — use `/shiplight:create_e2e_tests`
- You want to verify code changes look correct — use `/shiplight:verify`
- Tests pass but you want to improve test quality — manual review is better
- The application is intentionally being redesigned — rewrite tests instead

## Prerequisites

- A scaffolded Shiplight Playwright project with `playwright.config.ts`
- Existing `.test.yaml` files to triage
- The application under test is running and accessible
- Authentication configured (storage state files) if the app requires login

**Before editing any YAML test files**, you MUST:
1. **Read the YAML spec resource** — call `ReadMcpResourceTool` with uri `shiplight://yaml-test-spec-v1.3.0` to learn the correct YAML syntax. Key rules: use `intent:` (NOT `description:`), understand DRAFT vs ACTION vs STEP statement types, and know the correct field names.
2. **Read the action-entity schema** — call `ReadMcpResourceTool` with uri `shiplight://schemas/action-entity` to learn available actions and their parameters.
3. Optionally read the `/shiplight:create_e2e_tests` skill for authoring best practices.

Skipping step 1 leads to writing syntactically wrong tests (e.g., using `description:` instead of `intent:`, inventing non-existent action types). This wastes entire fix-run cycles.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Max retry cycles | 3 | How many fix → re-run cycles before marking a test as skipped. User can override. |

## Non-Interactive Mode (CI)

Triage is designed to run unattended in CI pipelines. When no user is present:
- **Never block on user input.** Make best-effort decisions and document them in the report.
- **Prefer conservative fixes** — update locators and assertions rather than restructuring flows when uncertain.
- **Mark ambiguous failures as skipped** rather than guessing wrong and introducing regressions.
- **Always produce the report file** — in CI, the report is the primary output for human review.

## Phase Overview

```
Phase 1: REPRODUCE  → Run tests, confirm real failures (filter env flakiness)
Phase 2: DIAGNOSE   → Classify each failure, separate test issues from app bugs
Phase 3: INVESTIGATE → Open concurrent browser sessions, inspect current UI state
Phase 4: FIX        → Edit YAML files, validate changes
Phase 5: VERIFY     → Re-run fixed tests, retry up to budget, report results
```

---

## Phase 1: Reproduce

> **Why run tests first:** Many test failures are caused by unstable environments — slow CI runners, flaky network, cold starts. If the healer can't reproduce a failure, there's nothing to fix.

1. **Identify the test target:**
   - If the user specified test files or directories, use those.
   - Otherwise, run the full suite.

2. **Run the tests:**
   ```bash
   npx shiplight test [target]
   ```
   Use `--headed` if running locally for easier debugging. Capture the full output.

3. **Parse results:**
   - Collect all failing tests: file path, test name, failing step, error message.
   - Collect all passing tests (to avoid touching them).
   - If all tests pass, report success and stop — nothing to triage.

4. **Filter environment flakiness:**
   - If a failure looks transient (network timeout, connection refused, server 502), consider re-running that specific test once to confirm it's reproducible.
   - Only proceed with consistently failing tests.

---

## Phase 2: Diagnose

For each failing test, classify the root cause **without opening a browser** — use the error message, the YAML file content, and the test output.

### A note on stale caches (locators and js assertions)

Shiplight YAML tests use a **cache + intent** architecture. Both `locator:` on ACTIONs and `js:` on VERIFYs are caches — when a cache fails, the runtime auto-heals by falling back to the natural language (`intent:` for actions, `VERIFY:` statement for assertions) and re-deriving via AI. The test still passes — it just runs slower (~5-10s instead of ~1s for that step).

Stale caches **do not cause test failures**. However, if the test output shows that auto-healing was triggered, triage should **update the stale caches** as an optimization. This keeps future runs fast and deterministic. Look for auto-healing signals in the test output and update `locator:` and `js:` fields during the investigation phase.

### Failure Classification

**Pre-classification from test output** — use error messages and test output to identify obvious categories before opening a browser:

| Category | Signal | Example | Action |
|----------|--------|---------|--------|
| `ASSERTION_DRIFT` | VERIFY fails with wrong value | Expected "Free shipping" but got "Standard shipping" | Update assertion |
| `TIMING_ISSUE` | Intermittent timeout, element appears after action | Spinner didn't clear before next step | Add/adjust WAIT_UNTIL or timeout |
| `AUTH_EXPIRED` | Redirect to login, 401 errors | Storage state expired | Re-authenticate and save new storage state |
| `NEEDS_INVESTIGATION` | Can't classify from output alone | Unclear error, ambiguous state | Investigate in browser |

**FLOW_CHANGED vs APP_BUG — determined during investigation, not pre-classification.**

These two categories look identical in test output ("test expected X but got Y"). The way to differentiate them is by checking whether the **test's intended flow is still achievable** in the current app:

1. Read the test's YAML flow — the sequence of `intent:` and `VERIFY:` statements describes what the test is trying to accomplish step by step. This is the source of truth for test intention, not the `goal` field (which may be stale).
2. During investigation, walk through the app and attempt to accomplish the same flow.
3. **If the flow is achievable via a different path** → `FLOW_CHANGED`. The app works, the test is outdated. Fix the test to match the new flow.
4. **If the flow is not achievable** (server errors, missing features, broken pages) → `APP_BUG`. The app is broken. Report the bug, do not modify the test.

Example:
- Flow intends to fill shipping info, then place order. Checkout now has a confirmation step between them → `FLOW_CHANGED` (flow achievable, path changed).
- Flow intends to fill shipping info, then place order. Checkout page returns a 500 error → `APP_BUG` (flow not achievable).

### Check for shared failure sources first

Before grouping, check if the failure originates from a shared component:

- **Suite hook failures** — if `beforeAll` or `beforeEach` fails, every test in the suite fails. Read the YAML suite structure and check if the error points to a hook step. Fixing one hook fixes all tests in the suite — don't investigate each test individually.
- **Template failures** — if the failing step comes from a `template:` reference, the fix belongs in the template file, not the test file. Check which tests use that template — the fix will affect all of them. Verify the fix doesn't break other consumers.
- **Function failures** — if the failing step uses `call:`, the issue may be in the TypeScript function, not the YAML. Check the function file.
- **Parameterized test variants** — if a parameterized test fails for some `parameters` variants but passes for others, the issue is likely data-specific (wrong test value, environment-dependent data), not a locator or flow problem. Check which variants fail and whether the fix should target the parameter values rather than the test steps.

### Grouping for efficiency

After classification:
- **Separate app bugs** — these go straight to the report, no browser investigation needed.
- **Group fixable failures by starting URL / page area** — tests that hit the same pages share an investigation session.
- **Flag UNKNOWN failures** — these need browser investigation to classify.

---

## Phase 3: Investigate

> **CRITICAL: Do NOT skip this phase.** Never guess what the UI looks like from reading source code, translation files, or component names. Always open a browser session and inspect the actual page. Source code tells you what _might_ render; the browser tells you what _does_ render. Guessing from source code leads to wrong fixes (e.g., assuming a button exists when it doesn't, or assuming a dropdown when it's actually a direct button).

Open concurrent browser sessions **using Shiplight MCP browser tools** (`new_session`, `inspect_page`, `act`, `get_locators`, etc.) to inspect the current state of the application. Each session covers a group of related failures (same page area or flow).

1. **Open sessions** — call `new_session` for each group, using the appropriate `starting_url` and `record_evidence: true` for CI traceability. Use `storage_state_path` if auth is needed. If the storage state is expired (page redirects to login), run the project's auth setup to generate a new one.

2. **Inspect current state** — for each session:
   - Call `inspect_page` to get the current DOM. **Read the DOM file first** for element indices.
   - Compare the current DOM against what the failing test expects.
   - Use `get_locators` to find updated locators for elements the test references.
   - Use `act` to walk through the flow the test covers — discover if steps were added, removed, or reordered.
   - Use `get_browser_console_logs` to check for JavaScript errors that indicate app bugs.
   - Use `get_browser_network_logs` to check for API failures.

3. **Reclassify if needed** — some failures classified as `UNKNOWN` or `LOCATOR_STALE` in Phase 2 may turn out to be `APP_BUG` or `FLOW_CHANGED` after browser inspection. Update the classification.

4. **Walk through the failing flow and capture locators** — for each fixable test:
   - Use `act` to replay the test's steps one by one in the browser, starting from where the test failed.
   - At each step, use `get_locators` to capture the Playwright locator and xpath for the target element.
   - Record the locator data — you will use it in Phase 4 to write enriched ACTION statements.
   - If a step no longer makes sense (e.g., a button was removed), discover the new flow and capture locators for the new steps.

5. **Build fix plan** — for each fixable test, document exactly what needs to change:
   - Which statements to update (by intent or position)
   - New locators captured from the browser (not guessed from source code)
   - New steps with locators, updated assertions
   - Any timing adjustments needed

6. **Close sessions** — call `close_session` for each. Keep the returned `local_video_path` and `local_trace_path` for the report.

---

## Phase 4: Fix

Edit each failing YAML test file based on the fix plan from Phase 3. Do not modify passing tests.

> **CRITICAL: Every new or updated step MUST be enriched with real locators.** During Phase 3 investigation, use `get_locators` to capture the actual Playwright locator and xpath for each element you interact with. Write enriched ACTION statements (`intent:` + `action:` + `locator:` + `xpath:`), NOT bare DRAFT statements (`intent:` only). DRAFTs are ~10s each and cause test timeouts. ACTIONs are ~1s each and replay deterministically.
>
> **Wrong** (bare DRAFT — slow, unreliable):
> ```yaml
> - intent: Click the checkbox next to the test case
> ```
>
> **Right** (enriched ACTION — fast, deterministic):
> ```yaml
> - intent: Click the checkbox next to the test case
>   action: click
>   locator: "locator('div').filter({ hasText: 'My Test Case' }).getByRole('checkbox')"
>   xpath: html/body/div[1]/main/.../input
> ```
>
> If you cannot get a stable locator (e.g., dynamic IDs like `#mantine-abc123`), use a DRAFT as a last resort, but prefer finding a stable alternative locator first via `get_locators` on neighboring elements.

### Cache optimization

For tests that passed but triggered auto-healing (stale `locator:` or `js:` caches), update the cache fields. This is not a fix — the test already passes — but it restores deterministic speed (~1s vs ~5-10s per healed step).

```yaml
# Before — cached locator is stale, runtime auto-heals via intent (slow)
- intent: Click the submit button
  action: click
  locator: "getByRole('button', { name: 'Submit' })"

# After — updated cache, deterministic replay (fast)
- intent: Click the submit button
  action: click
  locator: "getByRole('button', { name: 'Save changes' })"
```

```yaml
# Before — js assertion cache is stale, runtime falls back to VERIFY statement (slow)
- VERIFY: Order total shows the discounted price
  js: "await expect(page.getByText('$9.99')).toBeVisible({ timeout: 2000 })"

# After — updated cache, deterministic assertion (fast)
- VERIFY: Order total shows the discounted price
  js: "await expect(page.getByText('$7.99')).toBeVisible({ timeout: 2000 })"
```

### Fix strategies by category

**FLOW_CHANGED:**
- Add new steps where the flow now requires them.
- Remove steps that no longer apply.
- Reorder steps to match the current flow.
- Update `STEP:` containers if their child statements changed.
- Ensure new steps have proper `intent:` fields for future self-healing.

```yaml
# Before — single-page checkout
- intent: Click Place Order
  action: click
  locator: "getByRole('button', { name: 'Place Order' })"

# After — checkout now has a confirmation step
- intent: Click Continue to Review
  action: click
  locator: "getByRole('button', { name: 'Continue' })"
- intent: Confirm order details and place order
  action: click
  locator: "getByRole('button', { name: 'Place Order' })"
```

**ASSERTION_DRIFT:**

This is when the product has changed and the `VERIFY:` natural language statement itself describes outdated behavior. Unlike stale caches (where the AI fallback to the natural language still works), assertion drift means the AI fallback also fails because the assertion is wrong at the intent level.

- Update the `VERIFY:` statement to describe the current expected behavior.
- Update the `js:` cache to match (if present).
- If the feature was removed entirely, remove the `VERIFY:` step or replace it with what the product now shows.

```yaml
# Before — product removed the discount feature, both VERIFY and js are wrong
- VERIFY: Order total shows the discounted price
  js: "await expect(page.getByText('$7.99')).toBeVisible({ timeout: 2000 })"

# After — updated to reflect current product behavior
- VERIFY: Order total shows the full price
  js: "await expect(page.getByText('$9.99')).toBeVisible({ timeout: 2000 })"
```

**TIMING_ISSUE:**
- Add `WAIT_UNTIL:` before the failing step.
- Increase `timeout_seconds` on existing waits.
- Prefer `WAIT_UNTIL:` (AI-powered, self-healing) over `WAIT:` (fixed duration).

```yaml
# Add a wait before the step that was timing out
- WAIT_UNTIL: The loading spinner has disappeared
  timeout_seconds: 15
- intent: Click the dashboard chart
  action: click
  locator: "getByRole('img', { name: 'Revenue chart' })"
```

**AUTH_EXPIRED:**
- Do not edit YAML files for auth issues.
- Instead, use the project's auth setup script or Playwright's storage state generation to create a fresh storage state file.
- Re-run the affected tests after auth is refreshed.

**TEMPLATE_FAILURE:**
- Fix the template file (e.g., `templates/login.yaml`), not the test files that reference it.
- After fixing, identify all tests that use this template (search for `template: .../<filename>.yaml`).
- Re-run all affected tests, not just the one that was initially failing — a template fix can heal or break multiple tests.

**HOOK_FAILURE:**
- Fix the failing hook (`beforeAll`, `beforeEach`, `afterAll`, `afterEach`) in the suite YAML.
- A `beforeAll`/`beforeEach` fix typically unblocks every test in the suite — re-run the full suite after fixing.
- If a `beforeAll` hook fails due to missing data or environment setup, this may indicate an app bug or environment issue rather than a test issue.

**PARAMETER_VARIANT:**
- When only some parameter variants fail, check whether the parameter `values` are still valid (data may have changed in the test environment).
- Update the `values` in the `parameters` block rather than modifying the test steps.
- If the test steps themselves need to change, ensure the fix works for all variants, not just the failing one.

### Validate each fix

After editing a YAML file, call `validate_yaml_test` to ensure:
- The YAML is syntactically valid.
- Locator coverage meets the minimum threshold (50%+).
- No structural errors were introduced.

If validation fails, fix the issue before proceeding.

---

## Phase 5: Verify

Re-run only the fixed tests to confirm the fixes work.

1. **Run fixed tests:**
   ```bash
   npx shiplight test <fixed-file-1> <fixed-file-2> ...
   ```

2. **Evaluate results:**
   - **All pass** — fixes are confirmed, proceed to report.
   - **Some still fail** — enter a retry cycle:
     1. For each still-failing test, re-investigate in browser (repeat Phase 3 for that test only).
     2. Apply a refined fix (Phase 4).
     3. Re-run that specific test with an isolated report directory to avoid overwriting other test results:
        ```bash
        PLAYWRIGHT_HTML_REPORT=shiplight-report/triage/{test-name} npx shiplight test <test-file>
        ```
     4. Repeat up to the retry budget (default: 3 cycles).
   - **Retry budget exhausted** — mark the test as skipped:
     ```yaml
     skip: "Triage: unable to fix — <brief reason>. Needs manual investigation."
     ```

3. **Final run** — after all fixes and skips are applied, run the full target suite once to confirm no regressions were introduced by the fixes. Use a dedicated report directory for the final combined result:
   ```bash
   PLAYWRIGHT_HTML_REPORT=shiplight-report/triage/final npx shiplight test [target]
   ```

---

## Report

Generate a report saved to `shiplight-report/triage-{date}.md` and also summarize in the conversation. If investigation sessions were recorded (`record_evidence: true`), call `generate_html_report` with the video/trace paths and link the HTML report from the markdown report.

```markdown
# Triage Report
**Date:** {date}
**Target:** {test files or "full suite"}
**Total tests:** {count}
**Passing before triage:** {count}
**Failing before triage:** {count}

## Results

| Status | Count | Tests |
|--------|-------|-------|
| Healed | {n} | {list of test names} |
| Skipped | {n} | {list with skip reasons} |
| App Bug | {n} | {list with bug descriptions} |
| Already Passing | {n} | — |

## Healed Tests

For each healed test:
| Test | File | Failure Category | What Changed |
|------|------|-----------------|--------------|
| {name} | {file} | LOCATOR_STALE | Updated 2 locators |
| {name} | {file} | FLOW_CHANGED | Added confirmation step |
| {name} | {file} | TEMPLATE_FAILURE | Fixed shared login template |
| {name} | {file} | HOOK_FAILURE | Fixed beforeEach navigation |
| {name} | {file} | PARAMETER_VARIANT | Updated parameter values |

## App Bugs Detected

For each app bug:
### {test name}
- **File:** {path}
- **Symptom:** {what the test observed}
- **Evidence:** {error message, console logs, network errors}
- **Likely cause:** {assessment based on investigation}

## Skipped Tests

For each skipped test:
### {test name}
- **File:** {path}
- **Reason:** {why triage couldn't fix it}
- **Attempts:** {number of retry cycles used}

## Retry History

| Cycle | Tests Attempted | Fixed | Still Failing |
|-------|----------------|-------|---------------|
| 1 | {n} | {n} | {n} |
| 2 | {n} | {n} | {n} |
| 3 | {n} | {n} | {n} |

## Evidence
- Investigation recording: {link to HTML report if generated}
```

---

## Tips

- **Investigate all failures in the browser before writing any fix.** Don't do incremental "fix one, run, fix next" cycles. Investigate all failures upfront in Phase 3, capture all needed locators, then write all fixes in Phase 4, then run once to verify. Each test run takes minutes; wasted runs from wrong fixes add up fast.
- **Read the test output carefully** — the error message usually tells you the failure category without needing a browser.
- **Group aggressively** — if 5 tests fail on the checkout page, one browser session can investigate all 5.
- **Don't over-fix** — if a locator update is enough, don't restructure the test. Minimal changes are easier to review.
- **Intent quality matters** — when adding new steps, write specific intents that describe the user goal, not the DOM structure. Good intents are the foundation of future self-healing.
- **Check for app bugs first** — console errors, 500 responses, and blank pages are app bugs, not test issues. Report them, don't mask them with test changes.
- **Use concurrent sessions** — when investigating multiple page areas, open sessions in parallel to save time.
- **Auth issues are common** — if multiple tests fail with redirects to login, fix auth first before investigating individual tests.
- **Validate before re-running** — `validate_yaml_test` catches structural errors that would waste a test run.
