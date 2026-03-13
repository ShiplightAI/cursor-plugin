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

## Prerequisites

- **Node.js** >= 22
- **AI API key** — at least one of `ANTHROPIC_API_KEY` or `GOOGLE_API_KEY`

## Steps

### 1. Gather project info

Ask the user for:
- **Project path** — where to create the project (e.g., `./my-tests`)
- **Target URL** — the web app to test (e.g., `https://app.example.com`)
- **Login credentials** (if the app requires authentication) — URL, username, password, etc

### 2. Scaffold the project

Call `init_local_project` with the absolute project path. This creates:
- `package.json` with `shiplightai` and `@playwright/test`
- `playwright.config.ts` with `shiplightConfig()`
- `.env.example` with placeholder API keys
- `.gitignore` and `tests/` directory

### 3. Configure API keys

Create a `.env` file in the project directory with at least one AI API key:

```
ANTHROPIC_API_KEY=sk-ant-...
# or
GOOGLE_API_KEY=...
```

Ask the user which API key they want to use if not already known.

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
3. **Capture locators** — use `get_locator` for additional element info when needed.
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

- **ACTION is the default.** Capture locators via MCP tools (`act`, `get_locator`) during browser sessions, then write ACTION statements. ACTIONs replay deterministically (~1s).
- **DRAFT is a last resort.** Only use DRAFT when the locator is genuinely unknowable at authoring time. DRAFTs are slow (~5-10s each, AI resolution at runtime). Tests with too many DRAFTs are rejected by `validate_yaml_test`.
- **VERIFY for assertions.** Use `VERIFY:` for all assertions. Do not write assertion DRAFTs like `"Check that the button is visible"`.
- **URL for navigation.** Use `URL: /path` for navigation instead of `action: go_to_url`.
- **CODE for scripting.** Use `CODE:` for network mocking, localStorage manipulation, page-level scripting. Not for clicks, assertions, or navigation.

### ACTION: `js:` shorthand vs structured format

Every ACTION has a `desc` (ground truth) and a cache (`js` or `action`/`locator`). When the cache fails, the agent self-heals using the description.

**Prefer `js:` shorthand** for simple actions — it's more readable, more flexible, and the agent writes exactly the Playwright code it wants:

```yaml
# Click
- desc: Click the login button
  js: "await page.getByRole('button', { name: 'Login' }).first().click({ timeout: 5000 })"

# Press key
- desc: Press Escape to close dialog
  js: "await page.keyboard.press('Escape')"

# Hover
- desc: Hover over the menu
  js: "await page.getByRole('navigation').first().hover({ timeout: 5000 })"
```

**Do NOT use `action: click`**, `action: hover`, or `action: press` — use `js:` shorthand instead. These are simple Playwright one-liners that are more readable and flexible as `js:`.

**Use structured format** for actions that plain Playwright code doesn't handle well: `input_text` (handles clearing/focusing), `select_dropdown_option` (handles option resolution), `upload_file` (handles file input), `scroll` (handles scroll logic).

```yaml
- desc: Enter email address
  action: input_text
  locator: "getByPlaceholder('Email')"
  text: "user@example.com"
```

### `js:` coding rules

- Always resolve locators to a single element (e.g., `.first()`, `.nth(1)`) to avoid Playwright strict-mode errors
- Always include `{ timeout: 5000 }` on actions for predictable timing
- The `desc` is critical — it's the input for self-healing when `js` fails
- `page`, `agent`, and `expect` are available in scope
- Do NOT include `xpath` when using `js:` — xpath is only needed when an ACTION has neither `locator` nor `js`

### VERIFY best practices

- Always set a short timeout (e.g., `{ timeout: 2000 }`) on `js:` assertions that have an AI fallback, so stale locators fall back to AI quickly instead of waiting the default 10s
- Always use `VERIFY:` shorthand — do not use `action: verify` directly

### Waiting best practices

- **Do NOT use `action: wait` for hard sleeps.** Prefer assertion-based waiting instead.
- When waiting for a page/element to be ready, use a `VERIFY` with an appropriate timeout — this waits only as long as needed and fails fast if the condition is never met:

```yaml
# BAD: hard sleep then verify
- action: wait
  desc: Wait for page to load
  seconds: 3
- VERIFY: Dashboard is loaded
  js: "await expect(page.getByTestId('dashboard')).toBeVisible({ timeout: 2000 })"

# GOOD: single VERIFY with combined timeout
- VERIFY: Dashboard is loaded
  js: "await expect(page.getByTestId('dashboard')).toBeVisible({ timeout: 5000 })"
```

- If a hard sleep is truly necessary (e.g., waiting for an animation or background process with no observable state change), use `CODE:`:

```yaml
- CODE: "await page.waitForTimeout(3000)"
```

### General conventions

- Put `desc` first in ACTION statements for readability
- `xpath` is only needed when an ACTION has neither `locator` nor `js`.
- Single-test vs Suite: isolated test → single-test file; shared setup/teardown → suite; serial execution (shared state) → suite with `serial: true`; same structure, different data → `parameters`

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
