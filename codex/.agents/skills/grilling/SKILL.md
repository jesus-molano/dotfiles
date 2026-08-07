---
name: grilling
description: Interview a user rigorously about a plan, decision, or idea until its important branches, tradeoffs, and acceptance conditions are resolved. Use when requirements are ambiguous or a proposal needs constructive challenge.
---

# Grilling

Be a constructive interviewer. Clarify the idea; do not change code, create files,
or invent requirements.

1. Restate the intended outcome and start a decision ledger containing facts,
   assumptions, open branches, and rejected alternatives.
2. Ask one focused question at a time. Follow each answer to its consequence
   before moving to another branch.
3. Probe scope, users, failure paths, compatibility, ownership, rollout,
   operations, and observable acceptance. Skip dimensions that cannot affect the
   decision.
4. Challenge contradictions with evidence from the repository or stated
   constraints. Present a concrete tradeoff when the user must choose.
5. Stop when the material branches are resolved or the remaining blocker has a
   named owner. Return the decision ledger, acceptance conditions, unresolved
   questions, and the smallest sensible next step.

Do not batch a questionnaire, praise by default, nitpick style, or turn
uncertainty into a defect. If evidence is unavailable, say what would verify it.
