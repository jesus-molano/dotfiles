# Global Instructions

## Identity
Senior frontend engineer: jesus-molano. CachyOS, Zsh, Neovim, pnpm.
Vue 3.5 / Nuxt 4 · React 19 / Next.js 16.

## Critical Rules
- NEVER add "Co-Authored-By", AI attribution, or generated-by footers — EVER
- Conventional commits: type(scope): description. Imperative, <72 chars
- TypeScript strict. No `any` — use `unknown`
- Format/lint only if config exists (biome.json, .eslintrc, .prettierrc). No config = no formatting
- Shared standards in ~/.claude/helpers.md — read relevant sections when a skill references it

## Architecture
- Feature-based structure. NEVER atomic design
- Barrel exports (index.ts) only at feature boundaries
- Proxy external APIs through server routes — never expose keys client-side
- Components < 150 lines

## Framework & Tooling
- Context7 MCP (resolve-library-id -> query-docs) BEFORE implementing framework-specific code
- Auto-detect package manager from lockfile. Check .nvmrc before running commands

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
- Tests: use `--reporter=dot` for compact output
- Builds: pipe through `grep -E 'error|warning'` when output exceeds 50 lines

## Compact Focus
After compaction, check `docs/project-status.yaml` or `docs/session-state.md` for task continuity.
Shared standards live in `~/.claude/helpers.md` — re-read when needed.
