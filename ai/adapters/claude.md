# Claude Code adapter (CLI and the Code tab in Desktop)

- `AGENTS.md` loads next to `CLAUDE.md` in every project. Global rules never
  replace a repository contract. Do not create divergent parallel instructions.
- Invoke skills as `/name`. Roles: `reuse-scout` (Haiku, bounded search),
  `catalog-writer` (Sonnet, read-only Tessera card drafts) and four reviewers
  (Opus, high effort, read-only).
- Models by job: the main agent runs on Opus for execution and reasoning;
  reviewers use Opus with high effort; read-only search (`reuse-scout`, the
  built-in Explore agent) uses Haiku; bulk reading and drafting
  (`catalog-writer`) uses Sonnet. Do not switch the main model to save tokens;
  delegate reading instead.
- Auto mode approves routine actions. The `ai-guard` hook and the
  `permissions.deny` rules block the hard limits; every other human limit above
  still applies.
- In projects with a `project-gate` check, a blocked stop means the project's
  checks failed: fix the cause, never skip or weaken a check.
- Use plan mode for large or ambiguous changes. Use `/clear` between unrelated
  tasks and `/compact` with a focus hint in long ones.
- Linear: use the read-only `linear` server. Writes need a temporary MCP config
  and the `linear-workflow` skill. Keep tokens, auto memory and history out of dotfiles.
