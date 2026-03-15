---
description: Shared coding standards for architecture, quality, tooling, and memory leak prevention
---

# Shared Standards

## Architecture
- Feature-based structure. NEVER atomic design
- Named exports preferred. Default exports only for pages/layouts
- Barrel exports (index.ts) only at feature boundaries
- Components < 150 lines — split if exceeded
- Proxy external APIs through server routes — never expose keys client-side

## Quality
- Format/lint only if config exists: biome.json(c) → Biome, .eslintrc/.eslint.config → ESLint, .prettierrc/prettier.config → Prettier
- Surgical edits — never rewrite entire files

## Tooling
- Auto-detect package manager from lockfile: pnpm-lock.yaml → pnpm, bun.lockb → bun, yarn.lock → yarn, package-lock.json → npm
- Check .nvmrc / .node-version / engines before running commands
- Context7 MCP (resolve-library-id → query-docs) for framework docs

## Memory Leaks
- Event listeners cleaned up on unmount
- AbortController for fetches in effects/watchers
- Intervals/timeouts cleared
- No module-level component refs
