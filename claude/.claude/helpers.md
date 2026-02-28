# Shared Helpers

## Attribution
- NEVER add "Co-Authored-By", AI attribution, or generated-by footers — EVER

## TypeScript
- TypeScript strict. No `any` — use `unknown`
- Named exports preferred. Default exports only for pages/layouts

## Architecture
- Feature-based structure. NEVER atomic design
- Barrel exports (index.ts) only at feature boundaries
- Components < 150 lines — split if exceeded
- Proxy external APIs through server routes — never expose keys client-side

## Commits
- Conventional commits: type(scope): description
- Imperative mood, lowercase, no period, < 72 chars
- Types: feat, fix, refactor, docs, style, test, chore, perf, ci, build
- Breaking changes: `feat(auth)!: description`

## Quality
- Format/lint only if config exists: biome.json(c) -> Biome, .eslintrc/.eslint.config -> ESLint, .prettierrc/prettier.config -> Prettier. No config = no formatting
- Surgical edits — never rewrite entire files
- No console.log, debugger, or commented-out code in production
- Comments explain WHY not WHAT. TODOs must reference issues

## Tooling
- Auto-detect package manager from lockfile: pnpm-lock.yaml -> pnpm, bun.lockb -> bun, yarn.lock -> yarn, package-lock.json -> npm
- Check .nvmrc / .node-version / engines before running commands
- Context7 MCP (resolve-library-id -> query-docs) for Vue, Nuxt, React, Next.js

## Memory-Leaks
- Event listeners cleaned up on unmount
- AbortController for fetches in effects/watchers
- Intervals/timeouts cleared
- No module-level component refs
