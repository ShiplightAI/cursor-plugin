---
name: cloud
description: "Sync local test cases, templates, and functions with Shiplight cloud. Manage test runs, environments, folders, and accounts."
---

# Shiplight Cloud

Sync local YAML test cases, templates, and TypeScript functions with the Shiplight cloud using MCP tools. Manage test runs, environments, folders, and accounts via the REST API.

## Setup

A `SHIPLIGHT_API_TOKEN` is required. If cloud MCP tools (`save_test_case`, `get_test_case`, etc.) are not in the tool list, the token is missing.

Tell the user:
> Cloud tools are not available. Get your API token from https://app.shiplight.ai/settings/api-tokens, set `SHIPLIGHT_API_TOKEN` in your project's `.env` file, then reconnect MCP (`/mcp`).

If the user provides a token, append it to the project's `.env` file (create if needed) and tell them: "Saved to `<project>/.env` — make sure `.env` is in your `.gitignore`. Reconnect MCP (`/mcp`) to activate cloud tools."

All REST API calls require:
```
Authorization: Bearer $SHIPLIGHT_API_TOKEN
```

## Error Handling

| Error | Action |
|-------|--------|
| 401 Unauthorized | Token is invalid or expired — ask user to check `SHIPLIGHT_API_TOKEN` in `.env` |
| 403 Forbidden | Insufficient permissions — inform user |
| 404 Not Found | Resource not found — report to user |
| 422 Validation | Show validation message to user |
| Tool not found | Token is missing — guide user through setup above |

---

## MCP Tools

These tools are available when `SHIPLIGHT_API_TOKEN` is set. Prefer `file_path` over passing content directly (saves tokens). Always use `output_format: 'yaml'` for `get_test_case`.

- **Upload:** `save_test_case`, `save_test_account`, `save_template`, `save_function`
- **Download:** `get_test_case`, `get_template`, `get_function`
- **Account:** `save_test_account` — create/update test account with optional `storage_state_path` to upload local browser session to cloud

### ID Tracking

After uploading, add the returned cloud ID to the local file so future saves update instead of creating duplicates:

| Artifact | Local file | ID field |
|----------|-----------|----------|
| Test case | `*.test.yaml` | `test_case_id: 123` (top-level YAML field) |
| Template | `templates/*.yaml` | `template_id: 45` (top-level YAML field) |
| Function | `helpers/*.ts` | `@function_id 67` (JSDoc tag per export) |

---

## REST API

Base URL: `https://api.shiplight.ai`

### Test Cases

#### List Test Cases

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/test-cases
```

**Response:** array of `{ id, title, test_flow, folder_id }`

#### Get Test Case

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/test-cases/123
```

**Response:** `{ id, title, test_flow, folder_id }`

#### Update Test Case (partial)

For partial updates that don't involve `test_flow` (e.g. renaming):

```bash
curl -X PUT -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Login Flow"}' \
  https://api.shiplight.ai/v1/test-cases/123
```

**Request body:** (all fields optional)

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | New title |
| `test_flow` | object | Updated TestFlow JSON object (use `save_test_case` MCP tool instead for YAML sources) |
| `folder_id` | number | Move to a different folder |

#### Run Test Case

Triggers cloud execution. Returns a `test_run_id` for polling.

```bash
curl -X POST -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"trigger": "API", "environment": {"id": 1}}' \
  https://api.shiplight.ai/v1/test-run/test-case/123
```

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `trigger` | string | yes | Always `"API"` |
| `environment` | `{ id: number }` | no | Environment to run against (uses test case default if omitted) |

**Response:** `{ id, status, result, test_case_result_ids }`

---

### Test Runs

#### List Test Runs

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  "https://api.shiplight.ai/v1/test-runs?limit=10"
```

**Query parameters:**

| Param | Type | Description |
|-------|------|-------------|
| `testPlanId` | number | Filter by test plan |
| `trigger` | string | Filter by trigger (`"API"`, `"MANUAL"`) |
| `result` | string | Filter by result (`"PASSED"`, `"FAILED"`) |
| `limit` | number | Max results to return |

**Response:** array of `{ id, status, result, trigger, start_time, end_time, duration, total_test_case_count, passed_test_case_count, failed_test_case_count }`

#### Get Test Run Details

**Note:** This endpoint has **no `/v1/` prefix**.

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/run-results/456
```

**Response:**
```json
{
  "testRun": { "id": 456, "status": "COMPLETED", "result": "PASSED" },
  "testCaseResults": [
    { "id": 789, "test_case_id": 123, "result": "PASSED", "duration": 45 }
  ]
}
```

#### Get Test Case Result

**Note:** This endpoint has **no `/v1/` prefix**.

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/test-case-results/789
```

**Response:** `{ id, test_case_id, test_run_id, result, status, duration, environment_name, environment_url, video, trace, report_s3_uri, report, error }`

The `video`, `trace`, and `report_s3_uri` fields contain S3 URIs — use the Artifacts endpoint to download them.

The `report` field contains step-by-step execution details in `report[0].resultJson` — each step has `description`, `status`, `message`, `duration`, and artifact S3 URIs (`screenshot_s3_path`, `messages_s3_path`, etc.).

---

### Environments

#### List Environments

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/environments
```

**Response:** array of `{ id, name, url }`

#### Get Environment

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/environments/1
```

**Response:** `{ id, name, url }`

---

### Variables

Environment-scoped variables — the cloud equivalent of `variables` in `playwright.config.ts`. Use `isSensitive: true` for secrets (passwords, API keys) so they're masked in logs.

#### List Variables

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  "https://api.shiplight.ai/v1/variables?environmentId=1"
```

**Response:** array of `{ id, name, value, environment_id, is_sensitive }`

#### Create Variable

```bash
curl -X POST -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "username", "value": "testuser@example.com", "environmentId": 1}' \
  https://api.shiplight.ai/v1/variables
```

For sensitive values:

```bash
curl -X POST -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "password", "value": "secret123", "environmentId": 1, "isSensitive": true}' \
  https://api.shiplight.ai/v1/variables
```

#### Update Variable

```bash
curl -X PUT -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "new-value"}' \
  https://api.shiplight.ai/v1/variables/42
```

#### Delete Variable

```bash
curl -X DELETE -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/variables/42
```

---

### Test Accounts

#### List Test Accounts

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  "https://api.shiplight.ai/v1/test-accounts?environmentId=1"
```

**Query:** `environmentId` (number, optional but recommended) — filter by environment.

**Response:** array of `{ id, name, username, environmentId, loginConfig }`

#### Get Test Account

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/test-accounts/1
```

**Response:** `{ id, name, username, password, environmentId, loginConfig }`

#### Create Test Account

```bash
curl -X POST -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser@example.com",
    "password": "secret123",
    "name": "Test User",
    "environmentId": 1,
    "loginConfig": {
      "site_url": "https://app.example.com/login",
      "account": { "username": "testuser@example.com", "password": "secret123" }
    }
  }' \
  https://api.shiplight.ai/v1/test-accounts
```

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | string | yes | Account username/email |
| `password` | string | yes | Account password |
| `name` | string | no | Display name |
| `environmentId` | number | yes | Environment this account belongs to |
| `loginConfig` | object | no | Login automation config (`site_url` + `account` credentials) |

---

### Folders

#### List All Folders

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/test-folders/all
```

Optional query: `?search=keyword`

**Response:** array of `{ id, name, description, parentId, pathIds }`

#### List Folders by Parent

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  "https://api.shiplight.ai/v1/test-folders?parentId=1"
```

Omit `parentId` entirely for root-level folders.

**Response:** array of `{ id, name, description, parentId }`

#### Get Folder

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/test-folders/1
```

**Response:** `{ id, name, description, parentId, pathIds }`

#### Create Folder

```bash
curl -X POST -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Regression Tests", "description": "Weekly regression suite", "parentId": null}' \
  https://api.shiplight.ai/v1/test-folders
```

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Folder name |
| `description` | string | no | Folder description |
| `parentId` | number \| null | no | Parent folder ID (`null` for root) |

---

### Templates (Reusable Steps)

Reusable test step sequences that can be referenced from test cases via `template:` in YAML or `reference_id` in the cloud. The API uses the legacy name "reusable-steps".

#### Get Template

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/reusable-steps/138
```

**Response:** `{ id, name, description, statements }`

#### Update Template (partial)

For partial updates that don't involve `statements` (e.g. renaming):

```bash
curl -X PUT -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "dismiss-popup", "description": "Updated description"}' \
  https://api.shiplight.ai/v1/reusable-steps/138
```

**Request body:** (all fields optional)

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Template name |
| `description` | string | What the template does |
| `statements` | array | Statement objects (use `save_template` MCP tool instead for YAML sources) |

---

### Test Functions

Custom TypeScript functions that can be called from test cases via `call: "file#export"` in YAML.

#### Get Test Function

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  https://api.shiplight.ai/v1/functions/42
```

**Response:** `{ id, name, description, code, status }`

---

### Artifacts

#### Download S3 File

Download test artifacts (videos, traces, reports) referenced by S3 URIs in test case results.

```bash
curl -H "Authorization: Bearer $SHIPLIGHT_API_TOKEN" \
  "https://api.shiplight.ai/v1/s3/file?uri=s3://bucket/path/video.webm"
```

**Query:** `uri` (string, required) — S3 URI from test result fields (`video`, `trace`, `report_s3_uri`).

**Response:** raw file contents with appropriate content-type. For binary files (videos, traces), use `curl -o <output_file>` to save to disk.

---

## Workflows

### Sync local project to cloud

1. **Sync environment variables:** read `variables` from `playwright.config.ts`. List existing cloud variables with `GET /v1/variables?environmentId=<id>` first — create only variables that don't exist yet (`POST`), update ones that do (`PUT`). This avoids duplicates on repeated syncs.
2. **Sync test accounts:** call `save_test_account` with credentials and `storage_state_path` (if the local project uses storageState-based auth)
3. **Sync test cases:** find all `.test.yaml` files, call `save_test_case` with `file_path` for each. If the file already has a `test_case_id`, it updates; if not, it creates and returns an ID.
4. **Track IDs:** add the returned `test_case_id` to the YAML if not already present
5. **Sync templates and functions:** repeat with `save_template` and `save_function`

### Download test case from cloud

1. Call `get_test_case` with `test_case_id` and `output_format: 'yaml'`
2. Save the returned YAML to a `.test.yaml` file

### Run a test in the cloud and get results

1. `POST /v1/test-run/test-case/<id>` → triggers run, returns `{ id, test_case_result_ids }`
2. Poll `GET /run-results/<run_id>` every 10-15s until `testRun.status === "COMPLETED"` (**no `/v1/` prefix**)
3. `GET /test-case-results/<result_id>` → get `result`, `duration`, `error`, `video`, `trace` (**no `/v1/` prefix**)
4. If failed: check `error` field. Download artifacts with `GET /v1/s3/file?uri=<S3_URI>`

### Download test artifacts

1. `GET /test-case-results/<id>` → find `video`, `trace`, or `report_s3_uri` fields (S3 URIs)
2. `GET /v1/s3/file?uri=<S3_URI>` → download the artifact content
