---
name: engineering-flow
description: Guides a request to implement, add, build, change, refactor or fix code or configuration, from inspection through verification and handoff. Use before the first file edit. Not for research, review or diagnosis only, or for running an existing recipe.
---

# Engineering Flow

1. Read the nearest instructions, inspect the worktree, the owner path, tests
   and a comparable working pattern. Read a referenced ticket through the
   read-only tracker when available; do not invent acceptance criteria.
2. State the observable outcome, non-goals, constraints and any material
   assumption. Use the `clarify-change` skill only when inspection cannot
   resolve a consequential decision.
3. Before adding or replacing UI or behavior, follow
   [repository reuse](references/repository-reuse.md), including for small
   changes. Reuse evidence gathered earlier in the task.
4. For work that needs recoverable progress across meaningful steps or
   sessions, follow [task continuity](references/task-continuity.md). Small,
   understood changes need only a brief reuse decision and checks in the conversation.
5. Make the smallest cohesive change through the selected existing contracts.
   Use `test-driven-development` for an isolatable behavior change. Route a
   confirmed failure to `systematic-debugging`, or to `debug-web-flow` for a
   Next, Nuxt or Vue path that spans browser and server.
6. Run focused checks, the required repository checks and
   `verification-before-completion`. For web work use `playwright-cli` for
   browser checks. Inspect the complete task delta and report only evidence you obtained.
   A user correction that changes files starts a new delta: repeat steps 6 and 7
   for it before you report it done, even for a one-line fix.
7. Size independent review to the completed delta:
   - small or low risk: no agent reviewer, unless the change crosses a public,
     security, data, accessibility-critical or deployment boundary;
   - medium: one read-only reviewer (`reviewer-web` for web, otherwise
     `reviewer-standards`);
   - large or high risk: at least one read-only reviewer plus only the narrow
     specialists the changed domains justify.
   Give reviewers the delta, the test results and the reuse decision. Require
   file/line evidence and verify findings before changing code. Fix blockers,
   rerun the affected checks and request one fresh review. Stop after two
   review passes; report blocked or partial if a blocker remains.
8. Commit a coherent verified change when the governing instructions allow it.
   Keep the configured Git identity; never add `Co-authored-by`. Tracker
   writes, deployment and push need their own explicit authority.
9. Retro: if the task exposed a repeated failure or a user correction, propose
   one durable fix in the handoff: an `AGENTS.md` line, a hook, a test or a
   skill Gotcha. Never change global rules without the user's approval.
