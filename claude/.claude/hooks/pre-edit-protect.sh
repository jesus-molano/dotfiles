#!/usr/bin/env bash
# PreToolUse hook: block modifications to files with dynamic secret patterns
# Static patterns (.env, lockfiles, certs) are handled by permissions.deny

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ -z "$file_path" ]] && exit 0

basename=$(basename "$file_path")

# Block files with "secret" or "credential" in name (dynamic pattern)
case "$basename" in
  *secret*|*credential*)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Files containing secrets must not be modified."}}'
    echo "[$(date -Iseconds)] pre-edit-protect: BLOCKED secret ${file_path}" >&2
    exit 0
    ;;
esac

# Block .git internals
case "$file_path" in
  */.git/*|.git/*)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Git internals must not be modified directly."}}'
    echo "[$(date -Iseconds)] pre-edit-protect: BLOCKED .git ${file_path}" >&2
    exit 0
    ;;
esac

echo "[$(date -Iseconds)] pre-edit-protect: allowed ${file_path}" >&2
exit 0
