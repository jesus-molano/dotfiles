#!/usr/bin/env bash
set -uo pipefail

cat << 'RULES'
CRITICAL REMINDERS:
1. NEVER add Co-Authored-By or AI attribution to commits
2. Detect package manager from lockfile: pnpm-lock.yaml -> pnpm, bun.lockb -> bun, yarn.lock -> yarn, package-lock.json -> npm
3. Use Context7 MCP (resolve-library-id -> query-docs) for framework docs before coding
4. Model routing: Explore -> haiku, implementer/code-reviewer -> sonnet, arch-advisor/complex reasoning -> opus
5. Conventional commits: type(scope): description — imperative, lowercase, <72 chars
6. TypeScript strict, no `any` — use `unknown`
7. Shared standards in ~/.claude/helpers.md — read relevant sections when needed
RULES

echo ""
echo "SESSION CONTEXT:"

if git rev-parse --git-dir &>/dev/null 2>&1; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
  modified=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  echo "- Branch: ${branch} | Modified: ${modified} | Staged: ${staged}"
  git log --oneline -3 --no-decorate 2>/dev/null | sed 's/^/  /'
fi

[[ -f "docs/project-status.yaml" ]] && echo "- Status file: docs/project-status.yaml — read to resume"
[[ -f "docs/session-state.md" ]] && echo "- Handoff file: docs/session-state.md — read to resume"

exit 0
