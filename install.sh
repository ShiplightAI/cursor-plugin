#!/usr/bin/env bash
set -euo pipefail

# Shiplight Cursor Plugin Installer
# Installs MCP config and skills globally or into a specific project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Shiplight plugin for Cursor.

Options:
  --project <path>     Target project directory (default: current directory)
  --user              Install to user-level (~/.cursor) instead of current directory
  --help              Show this help message

Examples:
  bash install.sh                          # Install to current directory
  bash install.sh --user                   # Install to user-level (~/.cursor)
  bash install.sh --project ~/my-project    # Install to a specific project
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) TARGET="$HOME"; shift ;;
    --project)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --project requires a path"
        exit 1
      fi
      TARGET="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [ "$TARGET" = "$HOME" ]; then
  SCOPE="global (~/.cursor)"
else
  SCOPE="project ($TARGET/.cursor)"
fi
TARGET="$(cd "$TARGET" && pwd)"

echo "Installing Shiplight Cursor plugin..."
echo "  Destination: $TARGET/.cursor"
echo ""
read -r -p "Proceed with installation? [Y/n] " CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Installation cancelled."
  exit 0
fi
echo ""

# --- MCP config ---
MCP_FILE="$TARGET/.cursor/mcp.json"
mkdir -p "$TARGET/.cursor"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed. Install it with: brew install jq"
  exit 1
fi

if [ -f "$MCP_FILE" ]; then
  cp "$MCP_FILE" "$MCP_FILE.bak"
  echo "    Backed up -> $MCP_FILE.bak"

  jq -s '.[0] * {mcpServers: (.[0].mcpServers + .[1].mcpServers)}' \
    "$MCP_FILE.bak" "$SCRIPT_DIR/plugins/mcp-plugin/.mcp.json" > "$MCP_FILE"
  echo "    MCP config -> merged into $MCP_FILE"
else
  cp "$SCRIPT_DIR/plugins/mcp-plugin/.mcp.json" "$MCP_FILE"
  echo "    MCP config -> $MCP_FILE"
fi

# --- Skills ---
SKILLS="verify create_tests cloud"

for skill in $SKILLS; do
  SKILL_FILE="$TARGET/.cursor/skills/$skill/SKILL.md"
  mkdir -p "$(dirname "$SKILL_FILE")"
  if [ -f "$SKILL_FILE" ]; then
    cp "$SKILL_FILE" "$SKILL_FILE.bak"
    echo "    Backed up -> $SKILL_FILE.bak"
  fi
  cp "$SCRIPT_DIR/plugins/mcp-plugin/skills/$skill/SKILL.md" "$SKILL_FILE"
  echo "    /$skill skill -> $SKILL_FILE"
done

echo ""
echo "Done! Restart Cursor for the plugin to take effect."
echo ""
echo "Next steps:"
echo "  1. Open Cursor in your project"
echo "  2. Go to Settings (Cmd+Shift+J) -> MCP to confirm the Shiplight server"
echo "  3. Use /verify to test UI changes in a browser"
echo "  4. Use /create_tests to scaffold a local Shiplight test project"
echo "  5. Use /cloud to sync test cases with Shiplight cloud"
