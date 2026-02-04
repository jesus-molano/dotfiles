# Global Instructions

## Identity
Senior frontend engineer: jesus-molano. CachyOS, Zsh, Neovim, pnpm.
Vue 3.5 / Nuxt 4 · React 19 / Next.js 16.

## Critical Rules
- NEVER add "Co-Authored-By", AI attribution, or generated-by footers — EVER
- Conventional commits: type(scope): description. Imperative, <72 chars
- TypeScript strict. No `any` — use `unknown`
- Biome for format+lint when configured; ESLint+Prettier fallback

## Package Manager & Node Version
- Auto-detect package manager from lockfile: pnpm-lock.yaml → pnpm, bun.lockb → bun, yarn.lock → yarn, package-lock.json → npm
- ALWAYS check for .nvmrc, .node-version, or engines in package.json before running commands
- If no Node version file exists, suggest creating .nvmrc with current LTS

## Architecture
- Feature-based structure. NEVER atomic design
- Barrel exports (index.ts) only at feature boundaries
- Proxy external APIs through server routes — never expose keys client-side
- Components < 150 lines

## Framework Docs
- ALWAYS use Context7 MCP (resolve-library-id → query-docs) before implementing framework-specific code for Vue, Nuxt, React, Next.js
- Never rely on training data alone for framework APIs — check current docs first
- Current stack: Vue 3.5, Nuxt 4, React 19, Next.js 16

## Model Routing
- Exploration/search/read → Explore agent (Haiku, already default)
- Mechanical implementation of approved plans → implementer agent (Sonnet)
- Code reviews → code-reviewer agent (Sonnet)
- Architecture decisions → arch-advisor agent (Opus)
- Planning, debugging, complex reasoning → main conversation (Opus)
- Use `model: "sonnet"` on general-purpose Task calls when the task is straightforward implementation
- Use `model: "haiku"` on Task calls that only search, read, or gather info

## Token Efficiency
- Concise. No preambles, no restating questions
- Surgical edits — never rewrite entire files
- Delegate exploration to subagents (isolated context)
- Use Read with offset/limit for large files
