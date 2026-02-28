---
name: a11y-audit
description: Audit project for WCAG 2.1 AA accessibility compliance
disable-model-invocation: true
context: fork
agent: Explore
---

# Accessibility Audit (WCAG 2.1 AA)

Auto-detect framework and audit accordingly.

## Steps
1. Detect framework: look for `nuxt.config.ts` or `next.config.ts`
2. Read the detailed checklist from `~/.claude/skills/a11y-audit/REFERENCE.md`
3. Only run the section matching the detected framework + WCAG principles
4. Scan project files against each checklist item
5. Report findings grouped by WCAG principle

## Output Format

Group findings by WCAG principle:

### Critical (A violations)
Must fix — blocks users from accessing content.
Format: `file:line — WCAG criterion — issue — fix`

### Major (AA violations)
Should fix — significantly degrades experience.
Format: `file:line — WCAG criterion — issue — fix`

### Minor (Best practices)
Improvements for better UX.
Format: `file:line — issue — recommendation`
