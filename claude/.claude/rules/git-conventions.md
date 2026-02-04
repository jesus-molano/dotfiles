---
description: Git commit message conventions
globs:
  - "**/*"
---

# Git Conventions

## Commit Messages — Conventional Commits
- Format: `type(scope): description`
- Imperative mood, lowercase, no period at end
- Subject line < 72 characters
- Types: feat, fix, refactor, docs, style, test, chore, perf, ci, build
- Scope is optional but recommended (component, module, or feature name)
- Breaking changes: add `!` after type/scope — `feat(auth)!: remove session cookies`
- Body (optional): blank line after subject, wrap at 72 chars, explain WHY not WHAT

## Examples
- `feat(auth): add OAuth2 login flow`
- `fix(cart): prevent duplicate items on rapid clicks`
- `refactor(api): extract shared validation middleware`
- `chore(deps): bump vitest to v3`
