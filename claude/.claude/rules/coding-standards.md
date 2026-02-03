---
description: General coding standards for all projects
---

# Coding Standards

## Error Handling
- Explicit, typed error handling — never swallow errors silently
- Meaningful error messages that help debugging
- Handle promise rejections — no unhandled promises
- Use Result/Either patterns for expected failures, throw for unexpected
- Vue: `createError({ status, statusText })` (Nuxt 4 pattern)
- React: error boundaries for component trees, try/catch in Server Actions

## Testing
- Vitest for unit and component tests. Vitest Browser Mode for component rendering
- AAA pattern: Arrange → Act → Assert
- Test behavior, not implementation details
- One assertion focus per test (multiple related assertions OK)
- Use `describe` blocks for grouping, meaningful test names
- Mock external dependencies, not internal logic
- Vue: `mountSuspended` from @nuxt/test-utils for Nuxt components
- React: @testing-library/react with user-event

## Comments
- WHY not WHAT — code should be self-documenting
- TODOs must reference an issue: `// TODO(#123): description`
- Remove commented-out code — use git history instead
- JSDoc only for public APIs and complex function signatures

## Git
- One logical change per commit
- No console.log, debugger, or commented-out code in commits
- No AI attribution, Co-Authored-By, or generated-by footers — EVER
- Review staged diff before committing
- Conventional commit format: type(scope): description

## Dependencies
- Pin exact versions for critical deps
- Audit before adding — check bundle size, maintenance status, alternatives
- Prefer platform APIs over libraries (Intl, URL, fetch, structuredClone)
- One library per concern — don't mix competing solutions
