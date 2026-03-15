#!/usr/bin/env bash
set -uo pipefail

# Only remind if in a git repo with modified source files
git rev-parse --git-dir &>/dev/null || exit 0

MODIFIED=$(git diff --name-only 2>/dev/null | grep -cE '\.(ts|tsx|vue|js|jsx)$' || true)
[[ "$MODIFIED" -eq 0 ]] && exit 0

# Only if docs/ directory exists (project uses handoff pattern)
[[ -d "docs" ]] || exit 0

echo '{"additionalContext":"You have modified source files. Run /handoff before ending the session to preserve context."}'
echo "[$(date -Iseconds)] session-end: ${MODIFIED} source files modified, handoff recommended" >&2
exit 0
