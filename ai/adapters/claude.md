# Claude Code adapter (CLI and the Code tab in Desktop)

- `AGENTS.md` loads next to `CLAUDE.md` in every project. Global rules never
  replace a repository contract. Do not create divergent parallel instructions.
- Invoke skills as `/name`. Roles: `reuse-scout` (Haiku, bounded search),
  `catalog-writer` (Sonnet, read-only Tessera card drafts) and four reviewers
  (Opus, high effort, read-only).
- Keep the locally selected model and effort. Do not switch models to save
  tokens; delegate instead.
- `bypassPermissions` removes technical prompts. The `ai-guard` hook and the
  `permissions.deny` rules block the hard limits; every other human limit above
  still applies.
- Use plan mode for large or ambiguous changes. Use `/clear` between unrelated
  tasks and `/compact` with a focus hint in long ones.
- Linear: use the read-only `linear` server. Writes need a temporary MCP config
  and the `linear-workflow` skill. Keep tokens, auto memory and history out of dotfiles.
