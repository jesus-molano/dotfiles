#!/usr/bin/env bash
set -uo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[[ -z "$command" ]] && exit 0

# vitest sin reporter explicito -> agregar --reporter=dot
if echo "$command" | grep -qE '^\s*vitest\s+run' && ! echo "$command" | grep -q '\-\-reporter'; then
  new_command=$(echo "$command" | sed 's/vitest run/vitest run --reporter=dot/')
  jq -n --arg cmd "$new_command" '{updatedInput:{command:$cmd}}'
  exit 0
fi

# tsc/vue-tsc -> filtrar solo errores (usar pretty false para output limpio)
if echo "$command" | grep -qE '^\s*(tsc|vue-tsc)\s' && ! echo "$command" | grep -q '\-\-pretty'; then
  new_command="${command} --pretty false 2>&1 | head -50"
  jq -n --arg cmd "$new_command" '{updatedInput:{command:$cmd}}'
  exit 0
fi

exit 0
