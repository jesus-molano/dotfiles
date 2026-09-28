---
name: tessera
description: Look up, maintain and (on request) initialize a project's local Tessera catalog of reusable components and utilities, and run an optional provider decision (reuse, modify, wrap or create). Use when a task adds or replaces a component, utility, hook or reusable behavior in a project that has a Tessera catalog, or when the user asks to build or update one.
---

# Tessera

Tessera is personal tooling that keeps reusable-implementation knowledge per
project. Catalogs, history, tasks and runs live in local user storage outside
every Git repository, including personal dotfiles. The helper is
[scripts/tessera.py](scripts/tessera.py) (Python 3.11+ and Git; no server).
Claude and Codex use the same catalog and protocol.

## 1. Look up (normal path, cheap)

- Run `tessera.py status --repo PROJECT`. It is local, read-only and offline.
- `uninitialized`: no catalog. Use the ordinary reuse search from
  `engineering-flow`. Do **not** start `init` unless the user asks.
- `ready` or `needs_update`: run `tessera.py index --repo PROJECT`. It returns
  one short line per card (id, kind, name, tags, summary, source). Pick the
  plausible cards and read only those with
  `tessera.py card --repo PROJECT --id ID [--id ID ...]`. Never load the whole
  catalog into context.
- Verify each candidate against its source and one real consumer before you
  decide. The catalog guides the search; it does not replace reading code.
- If `status` is `needs_update`, run `tessera.py changes --repo PROJECT` and
  refresh the affected cards as part of the task (see "Maintain").

Documentation-only work, running checks and diagnosis need no Tessera call.

## 2. Maintain (incremental)

After a pull, a branch switch or your own change, `changes` compares the
checkout with the catalog's reviewed revision. For each affected card, read
the changed implementation and its non-test consumers, then refresh contract,
constraints and usages. Curate added sources and reconcile deleted or renamed
ones. Inspect `outside_catalog_changes` for new reusable pieces. Keep a copy of
the previous catalog in `history/`, set `reviewed_revision` only after the
inspection, then `scan`, `review` and `finalize` as
[lifecycle](references/lifecycle.md) describes. The tool detects changes; the
agent refreshes meaning. Never change a revision or date just to clear a warning.

## 3. Initialize (only when the user asks)

Follow [lifecycle](references/lifecycle.md): `init`, then `skeleton` for
deterministic starting evidence, then review every pending file in resumable
batches and `finalize`. Delegate card drafting to the `catalog-writer` role in
batches, grouped by the skeleton's evidence: trivial files (types, constants,
simple pages) in large batches, components with consumers in smaller ones. The
main agent validates and writes the cards. Initialization is a one-off cost;
state it before you start on a large repository.

## 4. Provider decision (optional, explicit)

`prepare` and `evaluate` send every card to an external decision provider
(Jev from TypeSafe, or Kev). This costs about 175k provider tokens per decision
on a 250-card catalog and its verdict picks one action for one card, so it
cannot express a composition of several pieces. Use it only when the user asks,
or when reuse is genuinely ambiguous between specific cards.

1. The user must have granted consent for this project and provider in their
   own terminal: `tessera.py consent --repo PROJECT --provider typesafe`.
   Never try to grant it yourself; the guard blocks it. For work projects this
   also requires the company's authorization to send project material out.
2. Decide first. Write the task JSON with `id`, `requirement`, `acceptance` and
   your own `agent_choice` (`action`, `primary` card id or null, `reason`).
   `prepare --require-ready` stores your choice locally and never sends it.
3. Inspect the prepared manifest (batches, maximum calls, destination) before
   `evaluate`. Credentials come only from the approved secret mechanism for
   that process. One run has one execution; there are no automatic retries.
4. Treat the result as evidence. The batch proposals in `calls/` are often more
   useful than the final verdict. `decided_by: coordinator` marks a result the
   rule derived without a provider call. Verify any choice against the source;
   never attribute your explanation to the provider.
5. `tessera.py report --repo PROJECT` shows decisions, agreement with your blind
   choices and provider tokens. Keep using the provider only while it changes
   decisions for the better.

## Rules

- Tests stay completely outside Tessera: never open, catalog, cite or send
  them. Path exclusions apply before any content is read, also for delegates.
- Never create `.tessera`, edit `.gitignore` or commit catalog data in a work
  repository, and never copy work catalogs to personal dotfiles or GitHub.
  `--allow-repo-storage` is only for an explicitly approved sharing of named files.
- Keep `reuse`, `modify`, `wrap`, `create` and `insufficient_evidence` distinct.
- Visual direction, project memory and task continuity have their own owners;
  Tessera records implementation knowledge and constraints only.

References: [lifecycle](references/lifecycle.md),
[contract and providers](references/contract.md),
[batch decisions](references/batching.md).
