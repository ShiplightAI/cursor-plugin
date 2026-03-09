#!/usr/bin/env bash
set -euo pipefail

# Shiplight Cursor Plugin Installer
# Installs MCP config and skills globally or into a specific project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
ALL=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Shiplight plugins for Cursor.

Options:
  --all               Install all plugins including Shiplight cloud
  --target <path>     Target project directory (installs per-project instead of global)
  --help              Show this help message

Examples:
  bash install.sh                          # Install globally (~/.cursor)
  bash install.sh --all                    # Install all plugins globally
  bash install.sh --target ~/my-project    # Install to a specific project
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL=true; shift ;;
    --target)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --target requires a path"
        exit 1
      fi
      TARGET="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [ "$ALL" = true ]; then
  EDITION="full (mcp-plugin + cloud-plugin)"
else
  EDITION="standard (mcp-plugin only)"
fi

if [ "$TARGET" = "$HOME" ]; then
  SCOPE="global (~/.cursor)"
else
  SCOPE="project ($TARGET/.cursor)"
fi

echo "Installing Shiplight Cursor plugins ($EDITION)..."
echo "  Scope: $SCOPE"
echo ""

# --- mcp-plugin: MCP config + /verify skill ---
echo "  Installing mcp-plugin..."

# Merge MCP config (add server without overwriting existing config)
MCP_FILE="$TARGET/.cursor/mcp.json"
mkdir -p "$TARGET/.cursor"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed. Install it with: brew install jq"
  exit 1
fi

if [ -f "$MCP_FILE" ]; then
  # Back up original before merging
  cp "$MCP_FILE" "$MCP_FILE.bak"
  echo "    Backed up -> $MCP_FILE.bak"

  # Merge new server into existing config
  jq -s '.[0] * {mcpServers: (.[0].mcpServers + .[1].mcpServers)}' \
    "$MCP_FILE.bak" "$SCRIPT_DIR/plugins/mcp-plugin/.mcp.json" > "$MCP_FILE"
  echo "    MCP config -> merged into $MCP_FILE"
else
  cp "$SCRIPT_DIR/plugins/mcp-plugin/.mcp.json" "$MCP_FILE"
  echo "    MCP config -> $MCP_FILE"
fi

# Copy verify skill
VERIFY_SKILL="$TARGET/.cursor/skills/verify/SKILL.md"
mkdir -p "$(dirname "$VERIFY_SKILL")"
if [ -f "$VERIFY_SKILL" ]; then
  cp "$VERIFY_SKILL" "$VERIFY_SKILL.bak"
  echo "    Backed up -> $VERIFY_SKILL.bak"
fi
cp "$SCRIPT_DIR/plugins/mcp-plugin/skills/verify/SKILL.md" "$VERIFY_SKILL"
echo "    /verify skill -> $VERIFY_SKILL"

# Copy create_yaml_tests skill
CREATE_TESTS_SKILL="$TARGET/.cursor/skills/create_yaml_tests/SKILL.md"
mkdir -p "$(dirname "$CREATE_TESTS_SKILL")"
if [ -f "$CREATE_TESTS_SKILL" ]; then
  cp "$CREATE_TESTS_SKILL" "$CREATE_TESTS_SKILL.bak"
  echo "    Backed up -> $CREATE_TESTS_SKILL.bak"
fi
cp "$SCRIPT_DIR/plugins/mcp-plugin/skills/create_yaml_tests/SKILL.md" "$CREATE_TESTS_SKILL"
echo "    /create_yaml_tests skill -> $CREATE_TESTS_SKILL"

# --- cloud-plugin: MCP config + /shiplight skill ---
if [ "$ALL" = true ]; then
  echo "  Installing cloud-plugin..."

  # Merge cloud MCP server into config
  if [ -f "$MCP_FILE" ]; then
    cp "$MCP_FILE" "$MCP_FILE.bak"
    jq -s '.[0] * {mcpServers: (.[0].mcpServers + .[1].mcpServers)}' \
      "$MCP_FILE.bak" "$SCRIPT_DIR/plugins/cloud-plugin/.mcp.json" > "$MCP_FILE"
    echo "    MCP config -> merged cloud server into $MCP_FILE"
  fi

  CLOUD_SKILL="$TARGET/.cursor/skills/shiplight/SKILL.md"
  mkdir -p "$(dirname "$CLOUD_SKILL")"
  if [ -f "$CLOUD_SKILL" ]; then
    cp "$CLOUD_SKILL" "$CLOUD_SKILL.bak"
    echo "    Backed up -> $CLOUD_SKILL.bak"
  fi
  cp "$SCRIPT_DIR/plugins/cloud-plugin/skills/shiplight/SKILL.md" "$CLOUD_SKILL"
  echo "    /shiplight skill -> $CLOUD_SKILL"
fi

echo ""
echo "Done! Restart Cursor for the plugins to take effect."
echo ""
echo "Next steps:"
echo "  1. Open Cursor in your project"
echo "  2. Go to Settings (Cmd+Shift+J) -> MCP to confirm the Shiplight server"
echo "  3. Use /verify to test UI changes in a browser"
echo "  4. Use /create_yaml_tests to scaffold a local Shiplight test project"
if [ "$ALL" = true ]; then
  echo "  5. Use /shiplight to manage cloud test cases"
  echo "  6. Set your API_TOKEN in Cursor Settings > MCP for the cloud server"
fi
