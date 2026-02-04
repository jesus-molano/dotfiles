#!/usr/bin/env bash
set -euo pipefail

# Setup Claude Code MCP servers in ~/.claude.json
# Run after `stow claude` on a new machine
# Requires: jq, npx

CLAUDE_JSON="$HOME/.claude.json"

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
