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
3. Make the smallest cohesive change. Reuse local boundaries and patterns.
   Use `$test-driven-development` for an isolatable behavior change. Route a
   confirmed failure to `$systematic-debugging`, or `$debug-web-flow` for a
   Next, Nuxt, or Vue path spanning browser and server.
4. Run focused checks, required repository checks, and `$verification-before-completion`.
   Inspect the diff and report only evidence actually obtained.
5. Commit a coherent verified change when the governing instructions allow it.
   Keep the configured Git identity; never add `Co-authored-by`. Tracker writes,
   deployment, and push need their own explicit authority and safety gates.
