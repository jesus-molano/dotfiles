---
name: tessera
description: Consult and maintain a project's Tessera component and utility catalog, and use a replaceable decision provider to choose reuse, modification, wrapping or creation for a software task.
---

# Tessera

Tessera is the project's versioned knowledge of reusable implementations.
The decision provider is replaceable: Jev/TypeSafe and Jared Palmer's Kev have
separate adapters; Kev requires an explicitly configured server.
Claude and Codex consume the same catalog, protocol and decision history.

## Route the task

- When a task adds or replaces a component, utility, hook or reusable behavior,
  inspect `.tessera/catalog.json` and the project's instructions. Consult this
  skill before implementation. For a material implementation choice, use the
  configured decision adapter with the task's requirements and acceptance checks.
- Documentation-only work, running checks and diagnosis without an implementation
  choice do not require a provider call. Do not turn this skill into a universal
  gate or call the service on every tool action.
- If the project has no catalog, inspect its actual contracts, consumers and
  tests; use the existing reuse-scout workflow to collect evidence. Create a
  scoped catalog only when that fits the authorized work. Mark incomplete
  coverage explicitly. No dependency on Atlas or its graph/state.
- Visual exploration belongs to the independent visual-direction/design
  capability, when available. Tessera records implementation knowledge and
  constraints, not inspiration, generated designs or aesthetic decisions.
- Keep project memory, ODD and task continuity in their existing owners. This
  skill neither replaces nor duplicates the project's workflow.

## Decide and implement

Read [the neutral contract and adapter protocol](references/contract.md) before
the first run. The helper is [scripts/tessera.py](scripts/tessera.py), relative to
this skill. Python 3.11+ and Git suffice; no global installation or server.

1. Read the whole catalog and the contracts relevant to the task. Refresh stale
   evidence. The catalog is not proof that the rest of the repository contains
   nothing useful: inspect and expand its declared scope when the task needs it.
2. Write a task JSON with `id`, `requirement` and `acceptance`. `prepare` assembles
   every catalog entry into a compact neutral decision context. Keep names,
   tags, contracts and constraints useful; tags alone do not prove a fit. Source,
   consumers, tests and styles stay in a separate local evidence snapshot; the
   provider receives their references, not full files. Do not preselect top-k
   candidates, filter entries by tags/relevance, or silently discard candidates
   to fit a provider limit. The chosen engine receives every curated card and
   decides; an exceeded limit is an explicit error. Do not introduce confidence
   gates without evaluation on the actual project.
3. Inspect the exact prepared context and destination before using `evaluate`.
   Credentials must be supplied through the project's approved secret mechanism
   to that process only; never put them in task files, catalog, logs or chat.
   Follow existing authorization for sending project material to an external
   provider. A prepared run is not a completed model decision.
4. Validate the decision's referenced ID and contract against the source. Keep
   `reuse`, `modify`, `wrap` and `create` distinct. Insufficient evidence, service
   errors or absent credentials remain explicit; never impersonate the provider
   or silently switch to a different model. Work independent of that decision
   can continue. One run permits one network attempt.
   If the cards lack a fact needed to decide, inspect the source and enrich the
   relevant contract or constraint, then prepare a fresh run. Never infer that
   the provider inspected a referenced file or that a listed test passed. Do not
   silently fall back to uploading all source when a compact query is unclear.
5. Explain the decision with source, consumer and test references. Label this as
   the implementing agent's explanation. Jev does not generate free text. Keep
   the raw provider decision immutable and record any disagreement separately.
6. Implement through the established engineering workflow, then test and review.
   Update the affected curated entries or add reusable components/utilities with
   stable IDs, actual usage and explicit test gaps. Regenerate derived evidence;
   do not overwrite curated knowledge with extracted data.

Commit reusable knowledge and reviewed decisions with the project when allowed.
Keep raw contexts and responses local by default; review their contents before
versioning. Record the catalog/context hash, provider/model, measured usage,
decision, agent explanation, implementation result and verification in the
project's decision log. Keep temporary progress in its existing task document.
