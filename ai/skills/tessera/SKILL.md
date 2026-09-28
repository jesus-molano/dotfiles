---
name: tessera
description: Initialize, check coverage and maintain a project's Tessera component and utility catalog; use a replaceable provider to choose reuse, modification, wrapping or creation for a software task.
---

# Tessera

Tessera is personal tooling with separate reusable-implementation knowledge for
each project. Catalogs and decision history live in local user storage outside
Git repositories by default, including outside personal dotfiles.
The decision provider is replaceable: Jev/TypeSafe and Jared Palmer's Kev have
separate adapters; Kev requires an explicitly configured server.
Claude and Codex consume the same catalog, protocol and decision history.

## Route the task

- When a task adds or replaces a component, utility, hook or reusable behavior,
  run `tessera.py status --repo PROJECT` to find its external catalog and read
  the project's instructions. Consult this skill before implementation. Use the
  configured decision adapter with the task's requirements and acceptance checks.
- Documentation-only work, running checks and diagnosis without an implementation
  choice do not require a provider call. Do not turn this skill into a universal
  gate or call the service on every tool action.
- If initialization, full review or an update is needed, follow
  [project lifecycle](references/lifecycle.md). Inventory the repository excluding tests
  and resume pending files in batches; use reuse-scout to fill actual evidence
  gaps. A current scoped catalog is not proof of complete project coverage.
  Never create `.tessera`, edit `.gitignore`, or commit personal tool data in a
  work repository. Do not copy work catalogs into personal dotfiles or GitHub.
  Repository-owned storage is an explicit sharing opt-in, never inferred from
  the presence of an old `.tessera` directory. Mark incomplete
  coverage explicitly. No dependency on Atlas or its graph/state.
- Visual exploration belongs to the independent visual-direction/design
  capability, when available. Tessera records implementation knowledge and
  constraints, not inspiration, generated designs or aesthetic decisions.
- Keep project memory, ODD and task continuity in their existing owners. This
  skill neither replaces nor duplicates the project's workflow.

Tests are completely outside Tessera: do not open or analyze them, search them
for consumers, catalog them, classify them as supporting evidence, or send their
paths/content to a provider. Apply the path exclusions in
[lifecycle](references/lifecycle.md) before any content inspection, including
when delegating to scouts. Running tests to verify an implementation remains the
responsibility of the engineering workflow, independent of catalog curation.

## Decide and implement

Read [the neutral contract and adapter protocol](references/contract.md) before
the first run. The helper is [scripts/tessera.py](scripts/tessera.py), relative to
this skill. Python 3.11+ and Git suffice; no global installation or server.

1. Before every decision, run `status` and follow its `next_action` using the
   [lifecycle](references/lifecycle.md). Reach `ready` through reviewed coverage
   and `finalize`; do not change a revision/date to clear pending work. For updates,
   `tessera.py changes --repo PROJECT` additionally compares
   the current checkout with the catalog's reviewed revision, including changes
   from colleagues after a pull or branch switch. For affected entries, read the
   changed implementation and non-test consumers; refresh contracts, constraints
   and usages. Curate added sources and reconcile deleted or
   renamed ones. Inspect `outside_catalog_changes` for reusable additions that
   need broader coverage. With a missing baseline, review the whole catalog.
   Preserve the previous catalog in local `history`, update the external catalog
   and set `reviewed_revision` only after inspection. Run `changes` again before
   finalizing and preparing the request. Do this as part of the task, without asking permission
   again for routine local curation. The tool detects changes; the agent refreshes
   meaning, not an automatic hash replacement. It does not fetch or pull remotely.
   Read the whole catalog; its scope is not proof that nothing useful exists elsewhere.
2. Write a task JSON with `id`, `requirement` and `acceptance`. Use
   `prepare --require-ready`; it checks full project coverage and assembles
   every catalog entry into a compact neutral decision context. Keep names,
   tags, contracts and constraints useful; tags alone do not prove a fit. Source,
   consumers and styles stay in a separate local evidence snapshot; the
   provider receives their references, not full files. Do not preselect top-k
   candidates, filter entries by tags/relevance, or silently discard candidates
   to fit a provider limit. Keep task files and runs in the external directories
   returned by `locate`; `prepare` defaults to that catalog and a new local run.
   The chosen engine evaluates every curated card in each decision. Large catalogs
   use exhaustive bounded batches followed by provider-selected proposal rounds;
   follow [batch decisions](references/batching.md). No agent prefiltering. A
   card that cannot fit whole is an explicit error, never truncated. Do not introduce confidence
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
   can continue. A run has one execution: one attempt per planned/provider-derived
   call, no automatic retries or replay after a partial failure. Inspect the
   prepared maximum call count before evaluation.
   If the cards lack a fact needed to decide, inspect the source and enrich the
   relevant contract or constraint, then prepare a fresh run. Never infer that
   the provider inspected a referenced file. Do not
   silently fall back to uploading all source when a compact query is unclear.
5. Explain the decision with source and consumer references. Label this as
   the implementing agent's explanation. Jev does not generate free text. Keep
   the raw provider decision immutable and record any disagreement separately.
6. Implement through the established engineering workflow, then test and review.
   Update the affected curated entries or add reusable components/utilities with
   stable IDs and actual non-test usage. Regenerate derived evidence;
   do not overwrite curated knowledge with extracted data. Scan/review/finalize
   the new clean revision so the next task can distinguish ready from stale.

Keep catalogs, history, tasks, raw contexts, responses and reviewed decisions in
the project's external local namespace. Record catalog/context hashes, provider,
model, usage, decision, agent explanation and verification there. Moving between
computers does not synchronize this data; work information stays on the work PC
unless an authorized transfer is explicitly requested. Dotfiles distributes the
tooling, not work knowledge. `--allow-repo-storage` is only for expressly approved
sharing of specified files; never use it to bypass the work-repository rule.
Keep ordinary task continuity in its existing owner.
