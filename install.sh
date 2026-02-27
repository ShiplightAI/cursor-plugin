#!/usr/bin/env bash
set -euo pipefail

# Shiplight Cursor Plugin Installer
# Installs MCP config and skills into a Cursor project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="."
ALL=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Shiplight plugins for Cursor.

Options:
  --all               Install all plugins including Shiplight cloud
  --target <path>     Target project directory (default: current directory)
  --help              Show this help message

Examples:
  bash install.sh                          # Install mcp-plugin to current project
  bash install.sh --all                    # Install all plugins
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

echo "Installing Shiplight Cursor plugins ($EDITION)..."
echo "  Target: $TARGET"
echo ""

# --- mcp-plugin: MCP config + /verify skill ---
echo "  Installing mcp-plugin..."

# Copy MCP config
mkdir -p "$TARGET/.cursor"
cp "$SCRIPT_DIR/plugins/mcp-plugin/.mcp.json" "$TARGET/.cursor/mcp.json"
echo "    MCP config -> $TARGET/.cursor/mcp.json"

# Copy verify skill
VERIFY_DIR="$TARGET/.cursor/plugins/shiplight-mcp/skills/verify"
mkdir -p "$VERIFY_DIR"
cp "$SCRIPT_DIR/plugins/mcp-plugin/skills/verify/SKILL.md" "$VERIFY_DIR/SKILL.md"
echo "    /verify skill -> $VERIFY_DIR/SKILL.md"

# --- cloud-plugin: /shiplight skill ---
if [ "$ALL" = true ]; then
  echo "  Installing cloud-plugin..."

  CLOUD_DIR="$TARGET/.cursor/plugins/shiplight-cloud/skills/shiplight"
  mkdir -p "$CLOUD_DIR"
  cp "$SCRIPT_DIR/plugins/cloud-plugin/skills/shiplight/SKILL.md" "$CLOUD_DIR/SKILL.md"
  echo "    /shiplight skill -> $CLOUD_DIR/SKILL.md"
fi

echo ""
echo "Done! Restart Cursor for the plugins to take effect."
echo ""
echo "Next steps:"
echo "  1. Open Cursor in your project"
echo "  2. Go to Settings (Cmd+Shift+J) -> MCP to confirm the browser server"
echo "  3. Use /verify to test UI changes in a browser"
if [ "$ALL" = true ]; then
  echo "  4. Use /shiplight to manage cloud test cases"
fi
