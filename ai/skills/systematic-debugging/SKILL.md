---
name: systematic-debugging
description: Diagnose a bug, test failure, build failure, or unexpected technical behavior before proposing a fix. Use for generic issues; route Next.js, Nuxt, or Vue browser-to-server flows to debug-web-flow.
---

# Systematic Debugging

1. Preserve the worktree and reproduce the smallest failing path. Record the
   command, input, environment boundary, actual result, and expected result.
2. Localize the failure with logs, traces, tests, history, or a minimal probe.
   Separate observed facts from inference.
3. Form one falsifiable cause hypothesis. Run the smallest check that can reject
   it. Do not stack speculative fixes or blame a dependency without evidence.
4. Apply the smallest correction after identifying the cause. Add a focused
   regression when practical, then rerun the reproduction and relevant checks.
5. Report cause, fix, evidence, and any unverified environment-dependent risk.

For a complete Next.js, Nuxt, or Vue flow involving UI, SSR, hydration,
navigation, forms, auth, network, or API boundaries, use `$debug-web-flow`.
