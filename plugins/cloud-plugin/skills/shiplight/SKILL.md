---
name: shiplight
description: "Shiplight test case creation, runs, environments, folders, and account management."
---

# Shiplight Cloud

Manage test cases, test runs, environments, folders, and accounts via the Shiplight REST API.

## API Setup

**Base URL:** `https://api.shiplight.ai` (override with `API_BASE_URL` env variable for non-production environments)

**Authentication:** All requests require:
```
Authorization: Bearer $API_TOKEN
```

### Token Resolution Order

Resolve `API_TOKEN` using this priority:

1. **Local credentials file** — read `~/.shiplight/credentials.json` → use the `token` field
2. **Environment variable** — check `$SHIPLIGHT_API_TOKEN` or `$API_TOKEN`
3. **`.env` file** — check `.env` in the current project directory

If none found, tell the user:
> No Shiplight API token found. Go to Cursor Settings > MCP, find the Shiplight Cloud server, and click **Authenticate** to log in. Then retry this command.

### Saving the Token After OAuth

After the user authenticates via MCP settings, the MCP server provides a `get_api_token` tool. Call it to retrieve the token, then save it locally:

```bash
mkdir -p ~/.shiplight && cat > ~/.shiplight/credentials.json << 'EOF'
{"token": "<TOKEN_FROM_MCP>"}
EOF
chmod 600 ~/.shiplight/credentials.json
```

### Handling Expired Tokens

If any API call returns **401**, the token is expired or revoked:

1. Delete the local credentials: `rm ~/.shiplight/credentials.json`
2. Tell the user: "Your API token has expired. Go to Cursor Settings > MCP, find Shiplight Cloud, and click **Re-authenticate**."
3. After re-auth, call `get_api_token` again and re-save to `~/.shiplight/credentials.json`.

**Optional headers:**
- `organization-id` — required for some endpoints with admin tokens

## Error Handling

| HTTP Status | Meaning              | Action                              |
|-------------|----------------------|-------------------------------------|
| 401         | Invalid/expired token | Delete `~/.shiplight/credentials.json`, prompt user to re-authenticate via Cursor Settings > MCP |
| 403         | Insufficient permissions | Inform user of permission issue |
| 404         | Resource not found   | Report missing resource             |
| 422         | Validation error     | Show validation message to user     |
| 429         | Rate limited         | Retry with exponential backoff      |
| 5xx         | Server error         | Suggest retrying or checking status |

---

## Test Cases

### List Test Cases

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/v1/test-cases
```

**Response:** array of `{ id, title, test_flow, folder_id }`

### Get Test Case

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/v1/test-cases/123
```

**Response:** `{ id, title, test_flow, folder_id }`

### Create Test Case

```bash
curl -X POST -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Login Flow",
    "test_flow": {
      "version": "1.2.0",
      "goal": "Verify user can log in",
      "url": "https://app.example.com/login",
      "statements": [
        {
          "uid": "step-1",
          "type": "ACTION",
          "description": "Enter email address",
          "action_entity": {
            "action_data": { "action_name": "input_text", "kwargs": { "value": "user@example.com" } },
            "element_index": 0
          }
        }
      ]
    },
    "folder_id": 1,
    "environment_configs": [
      {
        "environment_id": 1,
        "test_account_group": { "type": "None", "account_ids": [] },
        "path": ""
      }
    ]
  }' \
  https://api.shiplight.ai/v1/test-cases
```

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | yes | Test case name |
| `test_flow` | object | yes | TestFlow object (see schema below) |
| `folder_id` | number | no | Folder to place test case in |
| `environment_configs` | array | no | Environment + account configuration |

`environment_configs` items:

| Field | Type | Description |
|-------|------|-------------|
| `environment_id` | number | Environment ID (use List Environments to find) |
| `test_account_group.type` | `"None"` \| `"Specific"` \| `"Any"` | Account selection strategy |
| `test_account_group.account_ids` | number[] | Account IDs (for `"Specific"` type) |
| `path` | string | URL path appended to environment base URL |

**Response:** `{ success, message, test_case_id, title, folder_id, created_at }`

### Update Test Case

```bash
curl -X PUT -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Login Flow", "test_flow": {...}}' \
  https://api.shiplight.ai/v1/test-cases/123
```

**Request body:** (all fields optional)

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | New title |
| `test_flow` | object | Updated TestFlow object |

**Response:** `{ success, message, test_case_id, updated_at }`

### Run Test Case

Triggers cloud execution. Returns a `test_run_id` for polling.

```bash
curl -X POST -H "Authorization: Bearer $API_TOKEN" \
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

## Test Runs

### List Test Runs

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
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

### Get Test Run Details

**Note:** This endpoint has **no `/v1/` prefix**.

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
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

### Get Test Case Result

**Note:** This endpoint has **no `/v1/` prefix**.

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/test-case-results/789
```

**Response:** `{ id, test_case_id, test_run_id, result, status, duration, environment_name, environment_url, video, trace, report_s3_uri, error }`

The `video`, `trace`, and `report_s3_uri` fields contain S3 URIs — use the Artifacts endpoint to download them.

---

## Environments

### List Environments

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/v1/environments
```

**Response:** array of `{ id, name, url }`

### Get Environment

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/v1/environments/1
```

**Response:** `{ id, name, url }`

---

## Test Accounts

### List Test Accounts

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "https://api.shiplight.ai/v1/test-accounts?environmentId=1"
```

**Query:** `environmentId` (number, optional but recommended) — filter by environment.

**Response:** array of `{ id, name, username, environmentId, loginConfig }`

### Get Test Account

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/v1/test-accounts/1
```

**Response:** `{ id, name, username, password, environmentId, loginConfig }`

### Create Test Account

```bash
curl -X POST -H "Authorization: Bearer $API_TOKEN" \
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

**Response:** the created test account object

---

## Folders

### List All Folders

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/v1/test-folders/all
```

Optional query: `?search=keyword`

**Response:** array of `{ id, name, description, parentId, pathIds }`

### List Folders by Parent

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "https://api.shiplight.ai/v1/test-folders?parentId=1"
```

Omit `parentId` entirely for root-level folders.

**Response:** array of `{ id, name, description, parentId }`

### Get Folder

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  https://api.shiplight.ai/v1/test-folders/1
```

**Response:** `{ id, name, description, parentId, pathIds }`

### Create Folder

```bash
curl -X POST -H "Authorization: Bearer $API_TOKEN" \
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

**Response:** the created folder object

---

## Test Generation

### Generate Test from Goal

Uses AI to generate a test case from a natural language goal.

```bash
curl -X POST -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Login Flow",
    "startingUrl": "https://app.example.com/login",
    "goal": "Log in with valid credentials and verify dashboard loads",
    "environmentId": 1,
    "testAccountGroup": { "type": "Specific", "account_ids": [1] },
    "folderId": 1,
    "creation_mode": "SINGLE"
  }' \
  https://api.shiplight.ai/v1/test-batch-gen-tasks/create
```

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | yes | Test case name |
| `startingUrl` | string | yes | URL to start testing from |
| `goal` | string | yes | Natural language test goal |
| `environmentId` | number | yes | Environment to generate against |
| `testAccountGroup` | object | yes | Account config (`type` + `account_ids`) |
| `folderId` | number | no | Folder to place generated test in |
| `creation_mode` | string | yes | Always `"SINGLE"` |

**Response:** `{ testCase: { id, title, test_flow } }`

---

## Artifacts

### Download S3 File

Download test artifacts (videos, traces, reports) referenced by S3 URIs in test case results.

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "https://api.shiplight.ai/v1/s3/file?uri=s3://bucket/path/video.webm"
```

**Query:** `uri` (string, required) — S3 URI from test result fields (`video`, `trace`, `report_s3_uri`).

**Response:** file contents (JSON or plain text depending on file type)

---

## Workflows

### Create a test case end-to-end

1. `GET /v1/environments` → pick an environment ID
2. (Optional) `GET /v1/test-folders/all` → pick a folder ID
3. (Optional) `GET /v1/test-accounts?environmentId=<id>` → pick a test account
4. `POST /v1/test-cases` → create with `title`, `test_flow`, `folder_id`, `environment_configs`

### Run a test and get results

1. `POST /v1/test-run/test-case/<id>` → triggers run, returns `{ id, test_case_result_ids }`
2. Poll `GET /run-results/<run_id>` every 10-15s until `testRun.status === "COMPLETED"` (**no `/v1/` prefix**)
3. `GET /test-case-results/<result_id>` → get `result`, `duration`, `error`, `video`, `trace` (**no `/v1/` prefix**)
4. If failed: check `error` field. Download artifacts with `GET /v1/s3/file?uri=<S3_URI>`

### Generate a test case from a goal

1. `GET /v1/environments` → get environment ID; optionally `GET /v1/test-accounts?environmentId=<id>` for account
2. `POST /v1/test-batch-gen-tasks/create` → submit `title`, `startingUrl`, `goal`, `environmentId`, `testAccountGroup`, `creation_mode: "SINGLE"`
3. Response contains `{ testCase: { id, test_flow } }` — run it or inspect the flow

### Download test artifacts

1. `GET /test-case-results/<id>` → find `video`, `trace`, or `report_s3_uri` fields (S3 URIs)
2. `GET /v1/s3/file?uri=<S3_URI>` → download the artifact content

---

## TestFlow Schema

The `test_flow` object used in create/update test case:

```yaml
version: '1.2.0'
goal: 'Verify user can log in to dashboard'
url: 'https://app.example.com/login'
statements:
  - uid: 'step-1'
    type: 'ACTION'
    description: 'Enter email address'
    action_entity:
      action_data:
        action_name: 'input_text'
        kwargs: { value: 'user@example.com' }
      element_index: 0
  - uid: 'step-2'
    type: 'DRAFT'
    description: 'Verify dashboard is displayed'
# Optional: teardown section runs after test (same statement format)
```

### Required fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Always `"1.2.0"` |
| `goal` | string | What the test verifies |
| `url` | string | Starting URL |
| `statements` | array | Test steps |

### Statement types

| Type | Description | Has `action_entity`? |
|------|-------------|---------------------|
| `ACTION` | Concrete browser action with element target | Yes |
| `DRAFT` | Natural language step — AI resolves at runtime (~10-15s) | No |
| `STEP` | Group of nested statements | No (has `statements` array) |
| `IF_ELSE` | Conditional branch | No (has `then`/`else` arrays) |
| `WHILE_LOOP` | Loop | No (has `body` array) |

### Action names

Common actions (all require `element_index` in `action_entity` unless noted):

| Action | `kwargs` | Description |
|--------|----------|-------------|
| `click` | `{}` | Click element |
| `double_click` | `{}` | Double-click element |
| `input_text` | `{ value: "text" }` | Type into input field |
| `clear_input` | `{}` | Clear input field |
| `press` | `{ keys: "Enter" }` | Press keyboard key(s) |
| `select_dropdown_option` | `{ option: "Value" }` | Select from dropdown |
| `go_to_url` | `{ url: "https://..." }` | Navigate to URL |
| `go_back` | `{}` | Browser back |
| `scroll` | `{ direction: "down" }` | Scroll page |
| `scroll_to_text` | `{ text: "..." }` | Scroll until text visible |
| `wait` | `{ seconds: 3 }` | Wait fixed duration |
| `upload_file` | `{ file_path: "..." }` | Upload file to input |
| `verify` | `{ expected: "text" }` | Assert content exists (AI-powered) |
| `ai_extract` | `{ description: "..." }` | Extract data from page (AI-powered) |

Additional actions: `right_click`, `hover`, `send_keys_on_element`, `get_dropdown_options`, `set_date_for_native_date_picker`, `scroll_on_element`, `reload_page`, `switch_tab`, `close_tab`, `wait_for_page_ready`, `wait_for_download_complete`, `save_variable`, `ai_wait_until`, `generate_2fa_code`
