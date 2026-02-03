---
name: review-pr
description: Review a pull request for code quality, security, performance, and accessibility
context: fork
agent: code-reviewer
arguments:
  - name: pr
    description: PR number or branch name (defaults to current branch)
---

# PR Code Review

## Steps

1. Get the PR diff:
   ```bash
   gh pr diff ${pr:-$(git branch --show-current)} --color=never
   ```
   If no PR number given, use current branch.

2. Get PR metadata:
   ```bash
   gh pr view ${pr:-$(git branch --show-current)} --json title,body,files,additions,deletions
   ```

3. Review the diff against this checklist:

### Code Quality
- [ ] TypeScript strict — no `any`, proper type narrowing
- [ ] No unused variables, imports, or dead code
- [ ] DRY — no duplicated logic (extract composables/hooks)
- [ ] Components under 150 lines
- [ ] Named exports (default only for pages/layouts)
- [ ] Conventional commit messages

### Security
- [ ] No API keys, secrets, or credentials in client code
- [ ] External APIs proxied through server routes
- [ ] Input validation (Zod schemas for user input)
- [ ] No innerHTML/v-html with user data (XSS)
- [ ] CSRF protection on mutations

### Performance
- [ ] No unnecessary re-renders (Vue: shallowRef, React: React Compiler compatible)
- [ ] Lazy loading for heavy components/routes
- [ ] Images optimized (NuxtImage / next/image)
- [ ] No barrel file re-exports causing bundle bloat

### Memory Leaks
- [ ] Event listeners cleaned up (onUnmounted / useEffect cleanup)
- [ ] AbortController for fetch in watchers/effects
- [ ] Intervals/timeouts cleared
- [ ] Subscriptions unsubscribed

### Accessibility
- [ ] Semantic HTML elements
- [ ] ARIA attributes where needed
- [ ] Keyboard navigation support
- [ ] Focus management for modals/dialogs

### Testing
- [ ] New logic has tests
- [ ] Tests cover edge cases
- [ ] No test implementation details (test behavior)

## Output Format

### Critical 🔴
Issues that must be fixed before merge.
Format: `file:line — description`

### Warnings 🟡
Issues that should be addressed.
Format: `file:line — description`

### Suggestions 🔵
Nice-to-have improvements.
Format: `file:line — description`

### Positives 🟢
Good patterns worth noting.
Format: brief description
