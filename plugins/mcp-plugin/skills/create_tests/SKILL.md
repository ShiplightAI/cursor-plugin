---
name: create_tests
description: "Scaffold a local Shiplight test project, configure credentials, and write YAML tests by walking through the app in a browser."
---

# Create Local YAML Tests

Set up a local Shiplight test project and write YAML test files by interacting with the target app in a real browser. Tests run with `npx shiplight test` — no cloud infrastructure required.

## When to use

Use `/create_tests` when the user wants to:
- Create a new local test project from scratch
- Add YAML tests for a web application
- Set up authentication for a test project

## Steps

### 1. Check API keys

Before anything else, check that the user has at least one LLM API key (`ANTHROPIC_API_KEY` or `GOOGLE_API_KEY`) — these are required for browser actions. Ask the user:

> To create tests, I need an Anthropic or Google API key for AI-powered browser interactions. Do you have one of these?

If provided, save it to the project's `.env` file (create if needed) and tell them: "Saved to `<project>/.env` — make sure `.env` is in your `.gitignore`." The MCP server must be reconnected (`/mcp`) for new keys to take effect.

If the key is already available (e.g. `act` tool works without error), skip this step.

### 2. Gather project info

Ask the user for:
- **Project path** — where to create the project (e.g., `./my-tests`)
- **Target URL** — the web app to test (e.g., `https://app.example.com`)
- **Login credentials** (if the app requires authentication) — URL, username, password, etc

**Cloud shortcut:** If cloud MCP tools are available (i.e. `SHIPLIGHT_API_TOKEN` is set), use the `/cloud` skill to fetch environments and test accounts from the cloud — this can pre-fill the target URL and login credentials, saving the user from entering them manually.

### 3. Scaffold the project

Call `scaffold_project` with the absolute project path. This creates:
- `package.json` with `shiplightai` and `@playwright/test`
- `playwright.config.ts` with `shiplightConfig()`
- `.env.example` with placeholder API keys
- `.gitignore` and `tests/` directory

Save the API key from step 1 to the project's `.env` file.

### 4. Install dependencies

Run these commands in the project directory:

```bash
npm install
npx playwright install chromium
```

### 5. Set up authentication (if needed)

If the app requires login, follow the standard [Playwright authentication pattern](https://playwright.dev/docs/auth).

**a. Add credentials as variables** in `playwright.config.ts` using these standard names:

```ts
{
  name: 'my-app',
  testDir: './tests/my-app',
  dependencies: ['my-app-setup'],
  use: {
    baseURL: 'https://app.example.com',
    storageState: 'tests/my-app/.auth/storage-state.json',
    variables: {
      username: process.env.MY_APP_EMAIL,
      password: { value: process.env.MY_APP_PASSWORD, sensitive: true },
      // otp_secret_key: { value: process.env.MY_APP_TOTP_SECRET, sensitive: true },
    },
  },
},
```

Standard variable names: `username`, `password`, `otp_secret_key`. Use `{ value, sensitive: true }` for secrets so they are masked in logs. Add the actual values to `.env`.

**b. Write `auth.setup.ts`** with standard Playwright code (fill fields, click submit, save storage state). For apps that require 2FA/TOTP, the `otplib` package can generate time-based codes:

```ts
import { authenticator } from 'otplib';
const code = authenticator.generate(process.env.MY_APP_TOTP_SECRET!);
```

### 6. Write YAML tests

For each test the user wants to create:

1. **Open a browser session** — call `new_session` with the app's `starting_url`.
2. **Walk through the flow** — use `inspect_page` to see the page, then `act` to perform each action. This captures locators from the response.
3. **Capture locators** — use `get_locators` for additional element info when needed.
4. **Build the YAML** — construct the `.test.yaml` content following the best practices below.
5. **Save and validate** — write the `.test.yaml` file, then call `validate_yaml_test` with the file path to check locator coverage (minimum 50% required).
6. **Close the session** — call `close_session` when done.

**Important:** Do NOT write YAML tests from imagination. Always walk through the app in a browser session first to capture real locators. Tests without locators are rejected by `validate_yaml_test`.

### 7. Verify tests run

```bash
npx shiplight test
```

## YAML Format Reference

Read the MCP resource `shiplight://yaml-test-spec-v1.3.0` for the full language spec (statement types, templates, variables, suites, hooks, parameterized tests).

Read the MCP resource `shiplight://schemas/action-entity` for the full list of available actions and their parameters.

## YAML Authoring Best Practices

These best practices bridge the YAML language spec and the action catalog to help you write fast, reliable tests.

### Statement type selection

- **ACTION is the default.** Capture locators via MCP tools (`act`, `get_locators`) during browser sessions, then write ACTION statements. ACTIONs replay deterministically (~1s).
- **DRAFT is a last resort.** Only use DRAFT when the locator is genuinely unknowable at authoring time. DRAFTs are slow (~5-10s each, AI resolution at runtime). Tests with too many DRAFTs are rejected by `validate_yaml_test`.
- **VERIFY for assertions.** Use `VERIFY:` for all assertions. Do not write assertion DRAFTs like `"Check that the button is visible"`.
- **URL for navigation.** Use `URL: /path` for navigation instead of `action: go_to_url`.
- **CODE for scripting.** Use `CODE:` for network mocking, localStorage manipulation, page-level scripting. Not for clicks, assertions, or navigation.

### The `intent` field

`intent` is the **intent** of the step — it defines _what_ the step should accomplish. The `action`/`locator` or `js` fields are **caches** of _how_ to do it. When a cache fails (stale locator, changed DOM), the AI agent uses `intent` to re-inspect the page and regenerate the action from scratch.

Because `intent` drives self-healing, it must be specific enough for an agent to act on without any other context. Describe the **user goal**, not the DOM element — avoid element indices, CSS selectors, or positional references that break when the UI changes:

```yaml
# BAD: vague, agent can't re-derive the action
- intent: Click button

# BAD: tied to DOM structure that can change
- intent: Click the 3rd button in the form
- intent: Click element at index 42

# GOOD: describes the user goal, stable across UI changes
- intent: Click the Submit button to save the new project
  action: click
  locator: "getByRole('button', { name: 'Submit' })"
```

### ACTION: structured format vs `js:` shorthand

**Use structured format by default** for all supported actions. Read the MCP resource `shiplight://schemas/action-entity` for the full list of available actions and their parameters.

**Use `js:` only when the action doesn't map to a supported action** — e.g., complex multi-step interactions, custom Playwright API calls, or chained operations:

```yaml
- intent: Drag slider to 50% position
  js: "await page.getByRole('slider').first().fill('50')"

- intent: Wait for network idle after form submit
  js: "await page.waitForLoadState('networkidle')"
```

### `js:` coding rules

- Always resolve locators to a single element (e.g., `.first()`, `.nth(1)`) to avoid Playwright strict-mode errors
- Always include `{ timeout: 5000 }` on actions for predictable timing
- The `intent` is critical — it's the input for self-healing when `js` fails
- `page`, `agent`, and `expect` are available in scope

### VERIFY best practices

- Always set a short timeout (e.g., `{ timeout: 2000 }`) on `js:` assertions that have an AI fallback, so stale locators fall back to AI quickly instead of waiting the default 5s
- Always use `VERIFY:` shorthand — do not use `action: verify` directly

### Waiting best practices

- **Use `WAIT_UNTIL:` for smart waits** — AI checks the condition repeatedly until met or timeout:

```yaml
- WAIT_UNTIL: Dashboard data has finished loading
  timeout_seconds: 60

- WAIT_UNTIL: Spinner has disappeared
```

Default timeout is 60 seconds. Each AI condition check takes 10–15 seconds, so set `timeout_seconds` to at least 15. For waits under 10 seconds, use `WAIT:` instead.

- **Use `WAIT:` for short waits (<10s) or when no observable condition exists** (e.g., animations):

```yaml
- WAIT: Wait for animation to complete
  seconds: 3
```

### General conventions

- Put `intent` first in ACTION statements for readability
- `xpath` is only needed when an ACTION has neither `locator` nor `js`.
- Single-test vs Suite: isolated test → single-test file; shared setup/teardown or sequential tests with shared browser state → suite; same structure, different data → `parameters`

## Project Structure

```
my-tests/
├── playwright.config.ts
├── package.json
├── .env                          # API keys + credentials (gitignored)
├── .gitignore
│
├── tests/
│   ├── public-app/               # No login needed
│   │   ├── search.test.yaml
│   │   └── filter.test.yaml
│   │
│   └── my-saas-app/              # Requires login
│       ├── auth.setup.ts         # Playwright login setup — you write this
│       ├── dashboard.test.yaml
│       └── settings.test.yaml
```

## Tips

- ACTION statements with locators replay ~10x faster than DRAFTs. Always prefer ACTIONs.
- Use `inspect_page` to understand page state. **Always read the DOM file first** — it provides element indices needed for `act` and consumes far fewer tokens. Only view the screenshot when you specifically need visual information (layout, colors, images), as screenshots consume significantly more tokens than DOM.
- Run a specific project's tests with: `npx shiplight test my-saas-app/`
- The `.env` file is auto-discovered by `shiplightConfig()` — no manual dotenv setup needed.
