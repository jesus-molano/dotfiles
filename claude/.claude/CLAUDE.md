# Global Instructions

## Identity
Senior frontend engineer: jesus-molano. CachyOS, Zsh, Neovim, pnpm.
Specialization: Vue 3.5 / Nuxt 4 and React 19 / Next.js 16.

## Critical Rules
- NEVER add "Co-Authored-By", AI attribution, or generated-by footers to commits
- Conventional commits: type(scope): description. Imperative mood, <72 chars
- Types: feat, fix, refactor, style, docs, test, chore, perf, ci, build

## Code Style
- TypeScript strict mode everywhere. No `any` — use `unknown` if uncertain
- `const` over `let`. Never `var`. Arrow functions for callbacks
- Early returns over nested conditionals. Destructure at point of use
- Template literals over concatenation

## Imports
- Group: 1) framework/library 2) internal modules 3) types 4) styles/assets
- Use path aliases (@/, ~/, #/) when available
- Prefer named exports. Default exports only for pages/layouts

## Naming
- Components: PascalCase (UserProfile.vue, UserProfile.tsx)
- Composables/hooks: camelCase with `use` prefix (useAuth, useForm)
- Utils: camelCase (formatDate, parseQuery)
- Constants: SCREAMING_SNAKE_CASE
- Types/interfaces: PascalCase, no I prefix (User, not IUser)
- Files: kebab-case for non-components (api-client.ts)

## Architecture
- Feature-based directory structure. NEVER atomic design
- DRY: extract shared logic into composables (Vue) or hooks (React)
- Composition over inheritance. Always
- Colocate: tests next to source, types next to usage
- Components < 150 lines. Extract when exceeded
- Separate data fetching from presentation
- Proxy external APIs through server routes — never expose API keys client-side
- Use barrel exports (index.ts) only at feature boundaries

## Memory Leak Prevention
- Always cleanup: event listeners, intervals, timeouts, subscriptions
- Vue: use onUnmounted/onWatcherCleanup. React: useEffect cleanup returns
- AbortController for fetch requests in watchers/effects
- Never store component refs in module-level variables

## Tools
- pnpm as package manager. Never bun/yarn/npm for project deps
- Biome for formatting+linting when configured; ESLint+Prettier fallback
- Lefthook for git hooks. Commitlint for commit validation
- Vitest for unit/component tests. Playwright for e2e

## Token Efficiency (Max Plan)
- Be concise. No preambles ("Sure!", "Great question!"), no restating the question
- Don't explain changes unless logic is non-obvious or I ask
- Surgical edits — never rewrite entire files
- Batch related changes together
- Use Read with offset/limit for large files
- Delegate exploration to subagents (Explore = Haiku, isolated context)

## File Operations
- Check if file exists before creating. Respect project formatting
- Never modify lockfiles or .env files directly
