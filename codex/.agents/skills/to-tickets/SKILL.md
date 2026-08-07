---
name: to-tickets
description: Decompose an approved specification into independently reviewable implementation tickets with clear sequencing and acceptance criteria. Use when preparing a delivery backlog from a spec.
---

# To Tickets

Work only from an approved or clearly provisional spec. Split by independently verifiable outcomes, not technical layer labels.

For every ticket state: goal and non-goal; context and affected boundary; dependencies; implementation outline; acceptance criteria; test/verification plan; rollout or migration needs; risk. Keep each ticket small enough to review and revert. Order prerequisites before consumers, and make contracts or migrations explicit dependencies.

Use imperative language, stable paths or commands only when known, and observable
checkpoints. Separate facts from provisional assumptions and name the owner of
every unresolved decision. Do not create duplicate tickets for one cohesive
change or hide cross-ticket coupling.

Always produce and review local drafts first. Publishing to Linear is a separate
phase owned by explicit `$linear-workflow`: map the approved drafts to a verified team,
project, statuses, labels, and other live fields, preview the exact batch, then
obtain authorization immediately before the tracker writes. Decomposing a spec
never authorizes creating its tickets.
