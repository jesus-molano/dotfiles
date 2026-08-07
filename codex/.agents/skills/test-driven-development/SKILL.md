---
name: test-driven-development
description: Apply focused RED-GREEN-REFACTOR to an isolatable behavior change, regression, contract, error path, security rule, or accessible interaction. Invoke explicitly or when a parent implementation skill directs it.
---

# Test-Driven Development

Use test-first when a small automated example can distinguish new behavior from
the old one: logic, contracts, error handling, security rules, accessible
interactions, or a bug regression.

1. Name the observable behavior that a production change would break.
2. Write the smallest focused test and run it. Confirm it fails for the missing
   behavior, not a setup error.
3. Implement the minimum change, rerun the focused test, then required checks.
4. Refactor only while tests stay green.

Do not force TDD for documentation, declarative configuration, copy, or a pure
visual adjustment. Do not add a test framework for a small change. Instead run
the strongest existing direct verification and state the coverage gap. Never
delete or rewrite pre-existing work to manufacture RED; add a characterization
or regression test and disclose the limit when behavior already exists.
