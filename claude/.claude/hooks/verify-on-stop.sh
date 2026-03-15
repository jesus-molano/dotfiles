#!/usr/bin/env bash
# Stop hook: lightweight verification after Claude completes work
# Only runs if source files were modified and a test runner exists

set -euo pipefail

# Find project root
ROOT="$PWD"
while [[ "$ROOT" != "/" ]] && [[ ! -f "$ROOT/package.json" ]]; do
  ROOT="$(dirname "$ROOT")"
done

[[ "$ROOT" == "/" ]] && exit 0

# Check if any source files were modified (staged or unstaged)
cd "$ROOT"
MODIFIED=$(git diff --name-only --diff-filter=M 2>/dev/null | grep -E '\.(ts|tsx|vue|js|jsx)$' || true)
[[ -z "$MODIFIED" ]] && exit 0

# Run typecheck if available
if [[ -f "node_modules/.bin/vue-tsc" ]]; then
  npx vue-tsc --noEmit --pretty false 2>&1 | head -20 || true
elif [[ -f "node_modules/.bin/tsc" ]]; then
  npx tsc --noEmit --pretty false 2>&1 | head -20 || true
fi
