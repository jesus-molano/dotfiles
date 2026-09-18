---
name: engineering-flow
description: Implement a scoped feature, bug fix, refactor, or ready ticket from inspection through verification and concise handoff. Do not use for research-only, review-only, or diagnosis-only requests.
---

# Engineering Flow

1. Read the nearest instructions, inspect the worktree, owner path, tests, and
   comparable working pattern. Read a referenced ticket through the read-only
   tracker when available; do not invent acceptance criteria.
2. State the observable outcome, non-goals, constraints, and any material
   assumption. Use `$clarify-change` only when inspection cannot resolve a
   consequential decision.
3. Before adding or replacing UI or behavior, follow
   [repository reuse](references/repository-reuse.md), including small changes.
   If `frontend-task` already owns this task, use its existing reuse evidence
   and lock instead of starting another assessment. Otherwise this is a local
   code inspection, without Atlas preparation or a separate skill chain.
4. For work that needs recoverable progress across meaningful steps or sessions,
   follow [task continuity](references/task-continuity.md). Small, understood
   changes need only a brief reuse decision and checks in the conversation.
5. Make the smallest cohesive change using the selected existing contracts.
   Use `$test-driven-development` for an isolatable behavior change. Route a
   confirmed failure to `$systematic-debugging`, or `$debug-web-flow` for a
   Next, Nuxt, or Vue path spanning browser and server.
6. Run focused checks, required repository checks, and `$verification-before-completion`.
   Inspect the complete task delta and report only evidence actually obtained.
7. Apply independent review in proportion to the completed delta:
   - small/low: skip an agent reviewer unless the change crosses a public,
     security, data, accessibility-critical, or deployment boundary;
   - medium: use one independent read-only correctness/architecture reviewer;
   - large/high: use at least one independent read-only reviewer and add only
     the narrow specialists justified by the changed domains.
   Require file/line evidence. Verify findings before changing code. Fix
   blockers, rerun affected checks, and request one fresh review. Stop after two
   review passes; report blocked or partial if a blocker remains.
8. Commit a coherent verified change when the governing instructions allow it.
   Keep the configured Git identity; never add `Co-authored-by`. Tracker writes,
   deployment, and push need their own explicit authority and safety gates.
