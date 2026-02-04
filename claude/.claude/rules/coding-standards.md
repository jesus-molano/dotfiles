---
description: Coding standards enforcement for source code
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.vue"
  - "**/*.js"
  - "**/*.jsx"
---

# Coding Standards

## IMPORTANT — Error Handling
- NEVER swallow errors silently. Explicit typed error handling
- Handle ALL promise rejections — no unhandled promises
- Vue/Nuxt: `createError({ status, statusText })`. React: error boundaries + try/catch in Server Actions

## Testing (Vitest)
- AAA: Arrange → Act → Assert. Test BEHAVIOR, not implementation
- Mock external deps only, never internal logic
- Vue: `mountSuspended` from @nuxt/test-utils. React: @testing-library/react + user-event

## Comments & Code Hygiene
- WHY not WHAT. TODOs MUST reference issue: `// TODO(#123): desc`
- NEVER leave console.log, debugger, or commented-out code
- Prefer platform APIs (Intl, URL, fetch, structuredClone) over libraries
