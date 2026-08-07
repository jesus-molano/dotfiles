---
name: to-tickets
description: Decompose an approved specification into independently reviewable implementation tickets with clear sequencing and acceptance criteria. Use when preparing a delivery backlog from a spec.
---

# To Tickets

Work only from an approved or clearly provisional spec. Split by independently verifiable outcomes, not technical layer labels.

For every ticket state: goal and non-goal; context and affected boundary; dependencies; implementation outline; acceptance criteria; test/verification plan; rollout or migration needs; risk. Keep each ticket small enough to review and revert. Order prerequisites before consumers, and make contracts or migrations explicit dependencies.

Do not create duplicate tickets for one cohesive change or hide cross-ticket coupling. When the tracker write is not explicitly authorized, output draft tickets rather than changing external state.
