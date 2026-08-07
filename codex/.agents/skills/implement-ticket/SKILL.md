---
name: implement-ticket
description: Implement one software ticket safely by confirming its contract, making a focused change, and proving acceptance criteria. Use when a ticket is ready for engineering work.
---

# Implement Ticket

1. Read the ticket, linked spec, repository instructions, and current working tree. When given a Linear key or URL and its MCP is available, fetch the live issue read-only before restating scope, non-goals, and acceptance criteria.
2. Locate the owning code path and existing tests; resolve material ambiguity before implementation.
3. Make one coherent change. For behavior changes, use `$test-driven-development`; for failures, use `$systematic-debugging`.
4. Verify every acceptance criterion with focused checks, then required project checks. Inspect the final diff for scope drift.
5. Report changed files, evidence, migration/rollout effects, and follow-ups. Use `$linear-workflow` for any proposed tracker mutation and pass its preview and authorization gate.

Do not fold unrelated cleanup into the ticket. Preserve other worktree changes
and never include secrets in logs or summaries. After validation, show the
intended commit scope and ask for explicit confirmation immediately before
committing. Do not add `Co-authored-by` attribution for an agent, tool, or
upstream author. Never push, deploy, apply configuration, or mutate another
external system unless that exact action was authorized. Implementation,
validation, commit, push, merge, and Linear status or comment updates are
independent permissions; one never implies another.
