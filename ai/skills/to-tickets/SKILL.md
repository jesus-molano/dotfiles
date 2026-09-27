---
name: to-tickets
description: Decompose an approved specification into independently reviewable implementation tickets with clear sequencing and acceptance criteria. Use when preparing a delivery backlog from a spec.
---

# To Tickets

Work only from an approved or clearly provisional spec. Split by independently
verifiable outcomes, not technical layer labels. Prefer a vertical slice that
delivers a demonstrable result through only the layers it needs; do not create
separate tickets for UI, API, and storage unless the dependency is real.

For every ticket state: goal and non-goal; context and affected boundary;
real dependencies; implementation outline; acceptance criteria;
test/verification plan; rollout or migration needs; risk. Keep each ticket small
enough to review and revert. Order prerequisites before consumers, and make
contracts or migrations explicit dependencies.

For a cross-cutting migration, use expand-contract when compatibility requires
it: introduce the new form, migrate real consumers, verify them, then remove the
old form in a later ticket. State the compatibility window and removal condition.
Do not impose this sequence on a cohesive replacement that has no live
compatibility constraint.

Use imperative language, stable paths or commands only when known, and observable
checkpoints. Separate facts from provisional assumptions and name the owner of
every unresolved decision. Do not impose a repository path, rewrite, or migration
shape that the spec and dependencies do not require. Do not create duplicate
tickets for one cohesive change or hide cross-ticket coupling.

Always produce and review local drafts first. Publishing to Linear is a separate
phase owned by explicit `$linear-workflow`: map the approved drafts to a verified team,
project, statuses, labels, and other live fields, preview the exact batch, then
obtain authorization immediately before the tracker writes. Decomposing a spec
never authorizes creating its tickets.
