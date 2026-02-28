---
name: perf-audit
description: Audit project for performance issues across Vue/Nuxt and React/Next.js
disable-model-invocation: true
context: fork
agent: Explore
---

# Performance Audit

Auto-detect framework and audit accordingly.

## Steps
1. Detect framework: look for `nuxt.config.ts` (Vue/Nuxt) or `next.config.ts` (React/Next.js)
2. Read the detailed checklist from `~/.claude/skills/perf-audit/REFERENCE.md`
3. Only run the section matching the detected framework + Shared Checks
4. Check memory leaks per `~/.claude/helpers.md#Memory-Leaks`
5. Scan project files against each checklist item
6. Report findings grouped by severity

## Output Format

Report findings grouped by severity:
1. **Critical** — Measurable performance impact, fix immediately
2. **Warning** — Potential impact, should address
3. **Opportunity** — Optimization opportunities

Each finding: `file:line — issue — recommendation`
