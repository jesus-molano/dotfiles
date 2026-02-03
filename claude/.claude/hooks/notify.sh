#!/usr/bin/env bash
# Notification hook: desktop notifications via notify-send (Hyprland/SwayNC)

set -euo pipefail

# Ensure notify-send is available
command -v notify-send &>/dev/null || exit 0

input=$(cat)
title=$(echo "$input" | jq -r '.title // "Claude Code"')
message=$(echo "$input" | jq -r '.message // "Task completed"')

notify-send \
  --app-name="Claude Code" \
  --urgency="low" \
  --expire-time=3000 \
  --hint=boolean:transient:true \
  "$title" \
  "$message" 2>/dev/null || true

exit 0
