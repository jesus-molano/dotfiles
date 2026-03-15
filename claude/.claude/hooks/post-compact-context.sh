#!/usr/bin/env bash
set -uo pipefail

echo "SESSION CONTEXT:"
echo "- CWD: $(pwd)"

if git rev-parse --git-dir &>/dev/null 2>&1; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
  modified=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  echo "- Branch: ${branch} | Modified: ${modified} | Staged: ${staged}"
  git log --oneline -3 --no-decorate 2>/dev/null | sed 's/^/  /'
else
  echo "- No git repo detected"
fi

[[ -f "docs/project-status.yaml" ]] && echo "- Status file: docs/project-status.yaml — read to resume"
[[ -f "docs/session-state.md" ]] && echo "- Handoff file: docs/session-state.md — read to resume"
[[ -d "docs/sdd" ]] && echo "- SDD workflows detected — use /sdd-status to check progress"

echo "[$(date -Iseconds)] session-start: context restored" >&2

# Persist environment variables for Bash tool inheritance
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  # Detect package manager
  if [ -f "pnpm-lock.yaml" ]; then
    echo 'export PKG_MANAGER=pnpm' >> "$CLAUDE_ENV_FILE"
  elif [ -f "bun.lockb" ]; then
    echo 'export PKG_MANAGER=bun' >> "$CLAUDE_ENV_FILE"
  elif [ -f "yarn.lock" ]; then
    echo 'export PKG_MANAGER=yarn' >> "$CLAUDE_ENV_FILE"
  elif [ -f "package-lock.json" ]; then
    echo 'export PKG_MANAGER=npm' >> "$CLAUDE_ENV_FILE"
  fi

  # Detect framework
  if [ -f "nuxt.config.ts" ] || [ -f "nuxt.config.js" ]; then
    echo 'export FRAMEWORK=nuxt' >> "$CLAUDE_ENV_FILE"
  elif [ -f "next.config.ts" ] || [ -f "next.config.mjs" ] || [ -f "next.config.js" ]; then
    echo 'export FRAMEWORK=next' >> "$CLAUDE_ENV_FILE"
  fi
fi

exit 0
