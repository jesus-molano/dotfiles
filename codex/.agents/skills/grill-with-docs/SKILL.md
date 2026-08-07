---
name: grill-with-docs
description: Interview a user about an ambiguous software idea while grounding decisions in repository documentation and current primary sources. Use before specifying a consequential change whose requirements or constraints are not yet settled.
---

# Grill With Docs

Establish the evidence set, then resolve the design with the user without
changing code or inventing requirements.

1. Read the nearest repository instructions, current design documents, glossary,
   and relevant code paths before asking questions.
2. Identify claims that depend on external behavior and prefer primary,
   version-matched sources. Record the source and date.
3. Start a decision ledger with verified facts, assumptions, open branches, and
   rejected alternatives.
4. Ask one focused question at a time and follow its consequence before moving
   to another branch. Probe only dimensions that can change the decision, such
   as users, failure paths, compatibility, ownership, rollout, operations, or
   observable acceptance.
5. Challenge contradictions with repository evidence or stated constraints and
   present a concrete tradeoff when the user must choose.
6. Stop when material branches are resolved or the remaining blocker has a
   named owner. Return the ledger, shared terminology, acceptance conditions,
   rejected alternatives, remaining unknowns, and smallest sensible next step.
   Update project documentation only when the user explicitly requests the exact
   write.

Do not batch a questionnaire, praise by default, or treat snippets, search
summaries, or stale secondary articles as authoritative. Never copy sensitive
configuration values into the review.
