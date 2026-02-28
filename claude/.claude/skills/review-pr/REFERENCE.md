# PR Review — Detailed Checklist

## Code Quality
- [ ] TypeScript strict — no `any`, proper type narrowing
- [ ] No unused variables, imports, or dead code
- [ ] DRY — no duplicated logic (extract composables/hooks)
- [ ] Components under 150 lines
- [ ] Named exports (default only for pages/layouts)
- [ ] Conventional commit messages

## Security
- [ ] No API keys, secrets, or credentials in client code
- [ ] External APIs proxied through server routes
- [ ] Input validation (Zod schemas for user input)
- [ ] No innerHTML/v-html with user data (XSS)
- [ ] CSRF protection on mutations

## Performance
- [ ] No unnecessary re-renders (Vue: shallowRef, React: React Compiler compatible)
- [ ] Lazy loading for heavy components/routes
- [ ] Images optimized (NuxtImage / next/image)
- [ ] No barrel file re-exports causing bundle bloat

## Memory Leaks
- [ ] Event listeners cleaned up (onUnmounted / useEffect cleanup)
- [ ] AbortController for fetch in watchers/effects
- [ ] Intervals/timeouts cleared
- [ ] Subscriptions unsubscribed

## Accessibility
- [ ] Semantic HTML elements
- [ ] ARIA attributes where needed
- [ ] Keyboard navigation support
- [ ] Focus management for modals/dialogs

## Testing
- [ ] New logic has tests
- [ ] Tests cover edge cases
- [ ] No test implementation details (test behavior)
