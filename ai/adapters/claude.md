# Claude Code adapter (CLI and the Code tab in Desktop)

- `AGENTS.md` loads next to `CLAUDE.md` in every project. Do not create
  divergent parallel instructions.
- Make file edits with the Edit or Write tools so hooks, deny rules and
  checkpoints see them. In Bash, run generators and formatters, but never edit
  with `sed -i`, heredocs or redirections.
- Write Bash tool commands in POSIX shell syntax, never fish syntax. Use
  absolute paths instead of a `cd` to the working directory.
- The `ai-guard` hook and the `permissions.deny` rules block the hard limits;
  every other limit above still applies.
- In projects with a `project-gate` check, a blocked stop means the project's
  checks failed: fix the cause, never skip or weaken a check.
- Suggest `/rewind` for a clean restart and `/clear` for an unrelated task.
- Linear: read through the read-only `linear` server; writes follow
  `linear-workflow`. Keep tokens, auto memory and history out of dotfiles.
