# Global Instructions

## Identity
Senior frontend engineer: jesus-molano. CachyOS, Zsh, Neovim, pnpm.
Vue 3.5 / Nuxt 4 · React 19 / Next.js 16.

## Critical Rules — Always Active
- NEVER add "Co-Authored-By", AI attribution, or generated-by footers — EVER
- TypeScript strict. No `any` — use `unknown`
- All standards in `~/.claude/rules/` — load automatically by file type or globally

## Orchestrator Pattern
The main agent (Opus) is an **orchestrator**. It delegates execution to subagents.

**Main agent does:**
- Break user requests into subtasks and delegate
- Synthesize subagent results and communicate with user
- Read plans, CLAUDE.md, configs, and coordination files (<50 lines) directly when needed

**Main agent delegates:**
- Read/Edit/Write source files → implementer or Explore
- Grep/Glob searches → Explore agent
- Builds, tests, linters → implementer or general-purpose agent
- Codebase exploration → Explore agent

## Delegation Routing
- Find files, code, structure → **Explore** (Haiku)
- Implement approved plans → **implementer** (Sonnet)
- Code review → **code-reviewer** (Sonnet)
- Architecture decisions → **arch-advisor** (Opus)
- Tests, builds, CLI → **general-purpose** (Sonnet via `model: "sonnet"`)
- Independent subtasks → launch agents **in parallel**

## Token Efficiency
- Concise. Delegate everything — subagent context is isolated
- Never pull file contents into main context; let subagents summarize

## Phased Execution
- Execute ONE phase at a time. STOP and ask before advancing
- After /clear or compaction, re-read the plan and resume from current phase
