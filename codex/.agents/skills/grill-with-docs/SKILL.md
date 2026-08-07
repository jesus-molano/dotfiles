---
name: grill-with-docs
description: Interview a user about an ambiguous software idea while grounding decisions in repository documentation and current primary sources. Use before specifying a consequential change whose requirements or constraints are not yet settled.
---

# Grill With Docs

Establish the evidence set, then use `$grilling` to resolve the design with the
user.

1. Read the nearest repository instructions, current design documents, glossary,
   and relevant code paths before asking questions.
2. Identify claims that depend on external behavior and prefer primary,
   version-matched sources. Record the source and date.
3. Interview one decision at a time. Contrast each answer with the evidence and
   expose the concrete tradeoff when they differ.
4. Finish with a decision ledger, shared terminology, acceptance conditions,
   rejected alternatives, and remaining unknowns. Return these in the response;
   update project documentation only when the user explicitly requests the exact
   write.

Do not treat snippets, search summaries, or stale secondary articles as
authoritative. Never copy sensitive configuration values into the review.
