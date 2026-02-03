#!/usr/bin/env bash
# PreToolUse hook: block modifications to protected files
# Returns JSON with decision: "block" or "approve"

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ -z "$file_path" ]] && exit 0

basename=$(basename "$file_path")

# Block lockfiles
case "$basename" in
  pnpm-lock.yaml|package-lock.json|yarn.lock|bun.lockb)
    echo '{"decision":"block","reason":"Lockfiles must not be modified directly. Use pnpm install instead."}'
    exit 0
    ;;
esac

# Block .env files
case "$basename" in
  .env|.env.*)
    echo '{"decision":"block","reason":"Environment files must not be modified by Claude. Edit manually."}'
    exit 0
    ;;
esac

# Block credential/secret files
case "$basename" in
  *.pem|*.key|*.cert|*.p12|*.pfx)
    echo '{"decision":"block","reason":"Credential files must not be modified."}'
    exit 0
    ;;
esac

case "$basename" in
  *secret*|*credential*)
    echo '{"decision":"block","reason":"Files containing secrets must not be modified."}'
    exit 0
    ;;
esac

# Block .git internals
case "$file_path" in
  */.git/*|.git/*)
    echo '{"decision":"block","reason":"Git internals must not be modified directly."}'
    exit 0
    ;;
esac

exit 0
