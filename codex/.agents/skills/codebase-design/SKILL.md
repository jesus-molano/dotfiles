---
name: codebase-design
description: Design maintainable codebase structure, module boundaries, dependency direction, and public contracts. Use before significant features, refactors, or cross-cutting changes.
---

# Codebase Design

Start from existing conventions and the domain, not a preferred architecture.

1. Map current entry points, modules, dependencies, data flow, and tests.
2. Name the responsibility and public contract of each proposed module. Keep callers dependent on stable abstractions, not internals.
3. Prefer one-way dependency flow; reject cycles and shared mutable ownership unless explicitly justified.
4. Design seams for unstable integrations and state which layer owns validation, authorization, persistence, and side effects.
5. Compare the smallest viable option with alternatives on change isolation, testability, migration, and operational cost.
6. Produce an incremental plan that can be reviewed and verified at each step.

Avoid framework-first folders and speculative layers. A boundary is useful only when it prevents a real class of change from spreading.
