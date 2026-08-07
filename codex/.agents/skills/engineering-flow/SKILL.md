---
name: engineering-flow
description: Plan and execute a software change end to end, from understanding the request through implementation, verification, and a concise handoff. Use for feature work, bug fixes, refactors, and scoped engineering tasks.
---

# Engineering Flow

Turn a request into a small, verifiable change. First inspect the repository, nearest instructions, existing patterns, and current working tree. State assumptions that materially affect scope.

## Flow

1. Define the observable outcome, non-goals, constraints, and acceptance checks.
2. Find the owning code path and a comparable working pattern before designing.
3. Choose the smallest design that preserves boundaries; record alternatives only when they change risk or cost.
4. For behavior changes, use `$test-driven-development`: show the focused test fail, implement the minimum, then keep it green.
5. Keep changes cohesive. Do not combine opportunistic cleanup with the requested change.
6. Run focused checks first, then the repository-mandated checks. Inspect the diff for unintended files.
7. Report outcome, files changed, validation actually run, and remaining uncertainty.

## Decision gates

- Missing or conflicting requirements: ask a focused question before changing durable behavior.
- A failure or surprising result: switch to `$systematic-debugging`; do not guess a fix.
- A design crosses domains or introduces new concepts: use `$domain-modeling` and `$codebase-design` first.
- Work is too broad: create or refine a spec with `$to-spec`, then split it with `$to-tickets`.
- A commit is ready: show the validated scope and ask for explicit confirmation
  immediately before committing. Never push, deploy, apply configuration, or
  mutate an external system unless that exact action was authorized.

Never claim a check passed unless it was run in the current environment. Do not expose credentials, tokens, private keys, or environment-file contents in commands, diffs, or handoffs.
