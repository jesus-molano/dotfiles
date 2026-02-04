#!/usr/bin/env bash
# Re-inject critical rules after context compaction
cat << 'RULES'
CRITICAL REMINDERS:
1. NEVER add Co-Authored-By or AI attribution to commits
2. Detect package manager from lockfile: pnpm-lock.yaml → pnpm, bun.lockb → bun, yarn.lock → yarn, package-lock.json → npm
3. Use Context7 MCP (resolve-library-id → query-docs) for framework docs before coding
4. Model routing: Explore → haiku, implementer/code-reviewer → sonnet, arch-advisor/complex reasoning → opus
5. Conventional commits: type(scope): description — imperative, lowercase, <72 chars
6. TypeScript strict, no `any` — use `unknown`
RULES
exit 0
