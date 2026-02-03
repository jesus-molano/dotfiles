#!/usr/bin/env bash
# SessionStart hook (compact): re-inject critical rules after context compaction

cat << 'RULES'
## Post-Compaction Reminders
1. NEVER add "Co-Authored-By" or AI attribution to commits
2. Conventional commits: type(scope): description — imperative mood, <72 chars
3. Use pnpm as package manager — never bun/yarn/npm
4. TypeScript strict mode, no `any` — use `unknown` if uncertain
5. Be concise, surgical edits — no preambles, no restating questions
RULES

exit 0
