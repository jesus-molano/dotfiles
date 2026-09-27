---
name: domain-modeling
description: Model ambiguous business concepts, invariants, lifecycle states, and boundaries before software design. Use when the user asks for a domain model or unresolved business rules block a decision; do not invoke for routine implementation.
---

# Domain Modeling

Model the domain before choosing tables, endpoints, or classes.

1. Extract domain terms from users and existing code; define a shared glossary and flag overloaded words.
2. Identify entities, value objects, events, actors, and commands. State identity, ownership, and lifecycle for each.
3. Write invariants as testable statements and enumerate valid and invalid state transitions.
4. Draw boundaries where language, ownership, consistency, or change cadence differs. Integrate boundaries through explicit contracts.
5. Validate the model with realistic scenarios, including rejection and recovery paths.

Keep technical mechanisms separate from domain rules. If a term remains ambiguous, record the decision needed rather than silently selecting a meaning.
