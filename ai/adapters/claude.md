# Claude Code adapter (CLI and the Code tab in Desktop)

- `AGENTS.md` loads next to `CLAUDE.md` in every project. Do not create
  divergent parallel instructions.
- Make file edits with the Edit or Write tools so hooks, deny rules and
  checkpoints see them. Use Bash to run commands, not to edit files.
- The `ai-guard` hook and the `permissions.deny` rules block the hard limits;
  every other limit above still applies.
- In projects with a `project-gate` check, a blocked stop means the project's
  checks failed: fix the cause, never skip or weaken a check.
- When the user starts an unrelated task in a long session, suggest `/clear`.
- Linear: read through the read-only `linear` server; writes follow
  `linear-workflow`. Keep tokens, auto memory and history out of dotfiles.
