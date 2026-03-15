#!/usr/bin/env bash
set -uo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[[ -z "$command" ]] && exit 0

# Block Bash writes to protected file patterns (security bypass mitigation)
if echo "$command" | grep -qE '(secret|credential|\.env|\.pem|\.key|\.cert|/\.git/|^\.git/)' ; then
  if echo "$command" | grep -qE '(sed\s+-i|echo\s+.*>{1,2}|cat\s+.*>{1,2}|\btee\b|python\s+-c\s+.*open\s*\(|\bcp\s+|\bmv\s+|>{1,2}\s*[^|&])' ; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Bash command writes to a protected file pattern"}}'
    echo "[$(date -Iseconds)] filter-output: BLOCKED write to protected pattern" >&2
    exit 0
  fi
fi

# vitest sin reporter explicito -> agregar --reporter=dot
if echo "$command" | grep -qE '^\s*vitest\s+run' && ! echo "$command" | grep -q '\-\-reporter'; then
  new_command=$(echo "$command" | sed 's/vitest run/vitest run --reporter=dot/')
  jq -n --arg cmd "$new_command" '{updatedInput:{command:$cmd}}'
  echo "[$(date -Iseconds)] filter-output: added --reporter=dot" >&2
  exit 0
fi

# tsc/vue-tsc -> filtrar solo errores (usar pretty false para output limpio)
if echo "$command" | grep -qE '^\s*(tsc|vue-tsc)\s' && ! echo "$command" | grep -q '\-\-pretty'; then
  new_command="${command} --pretty false 2>&1 | head -50"
  jq -n --arg cmd "$new_command" '{updatedInput:{command:$cmd}}'
  echo "[$(date -Iseconds)] filter-output: added --pretty false" >&2
  exit 0
fi

echo "[$(date -Iseconds)] filter-output: pass-through" >&2
exit 0
