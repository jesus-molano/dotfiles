#!/usr/bin/env bash
set -euo pipefail

# Setup Claude Code MCP servers in ~/.claude.json
# Run after `stow claude` on a new machine
# Requires: jq, npx

CLAUDE_JSON="$HOME/.claude.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load credentials from mcp.env (gitignored)
if [[ -f "$SCRIPT_DIR/mcp.env" ]]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/mcp.env"
else
  echo "Warning: $SCRIPT_DIR/mcp.env not found. Copy mcp.env.example and fill in values."
fi

MCP_CONFIG='{
  "context7": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp@latest"],
    "env": {}
  },
  "playwright": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@playwright/mcp@latest", "--browser", "chromium"],
    "env": {}
  },
  "sequential-thinking": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
    "env": {}
  },
  "linear": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"],
    "env": {}
  },
  "jira": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@aashari/mcp-server-atlassian-jira"],
    "env": {
      "ATLASSIAN_SITE_NAME": "'"${ATLASSIAN_SITE_NAME:-}"'",
      "ATLASSIAN_USER_EMAIL": "'"${ATLASSIAN_USER_EMAIL:-}"'",
      "ATLASSIAN_API_TOKEN": "'"${ATLASSIAN_API_TOKEN:-}"'"
    }
  }
}'

if [[ ! -f "$CLAUDE_JSON" ]]; then
  echo '{}' > "$CLAUDE_JSON"
  echo "Created $CLAUDE_JSON"
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: pacman -S jq"
  exit 1
fi

# Merge MCP servers into existing config (preserves all other fields)
jq --argjson mcp "$MCP_CONFIG" '.mcpServers = (.mcpServers // {}) * $mcp' "$CLAUDE_JSON" > "${CLAUDE_JSON}.tmp" \
  && mv "${CLAUDE_JSON}.tmp" "$CLAUDE_JSON"

echo "MCP servers configured in $CLAUDE_JSON:"
jq -r '.mcpServers | keys[]' "$CLAUDE_JSON"
