---
name: review-web-pr
description: Own the review of a Next.js, Nuxt or Vue branch or pull request, including checks against its specification. Use when the user asks to review a web branch, compare it with its base or check a web PR; stays read-only unless a fix is requested separately.
---

# Review a Web PR

## Set the scope

1. Read the repository instructions and check the local state.
2. Resolve the base from the PR metadata or the upstream; do not assume `main`
   if Git says otherwise.
3. Read the complete diff and trace the affected execution paths before judging.
4. Stay read-only. Do not fix findings unless the user asks.

## Review by risk

In this order:

1. Correctness, regressions and race conditions.
2. Trust boundaries: authentication, authorization, validation and data exposure.
3. SSR, hydration, caching, navigation and async states.
4. Keyboard accessibility, focus, accessible names and semantics.
5. Measurable performance: waterfalls, bundles, renders and redundant queries.
6. Test coverage and observability.

For new UI or functionality, compare the reuse decision with the existing
component, wrapper or function and one real usage. Report duplication and
drift from supported components and tokens with paths and concrete
consequences (behavior, accessibility, consistency or maintenance). Do not
demand an incompatible abstraction, and do not treat established native HTML
as duplication.

Use `reviewer-web` or up to three subagents only when the axes are independent
and the diff justifies it. Give each one the base, the range and any check
results, and wait for every report before you write yours. Avoid style-only
comments, hypotheses without a code path and generic advice.

## Validate findings

Reproduce or run the smallest check that confirms each risk. Consult primary
documentation when a finding depends on a specific Next, Nuxt or Vue version or
a browser API.

## Report

List findings by severity with file/line, observable behavior, evidence and the
minimal fix. If there are no findings, say so and name residual risks or checks
that could not run.
