#!/usr/bin/env bash
# InstructionsLoaded hook: log which instruction files are loaded and why
# Useful for debugging path-specific rules that don't trigger as expected

set -uo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')
load_reason=$(echo "$input" | jq -r '.load_reason // empty')
memory_type=$(echo "$input" | jq -r '.memory_type // empty')

[[ -z "$file_path" ]] && exit 0

echo "[$(date -Iseconds)] instructions-loaded: ${memory_type} | ${load_reason} | ${file_path}" >&2
exit 0
