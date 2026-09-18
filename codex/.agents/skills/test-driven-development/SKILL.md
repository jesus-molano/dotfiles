---
name: test-driven-development
description: Apply focused RED-GREEN-REFACTOR to an isolatable behavior change, regression, contract, error path, security rule, or accessible interaction. Invoke explicitly or when a parent implementation skill directs it.
---

# Test-Driven Development

Use test-first when a small automated example can distinguish new behavior from
the old one: logic, contracts, error handling, security rules, accessible
interactions, or a bug regression.

1. Name the observable behavior through its public interface: a user-visible
   result, API contract, event, or stable boundary that a production change
   would break.
2. Write the smallest focused test with an expected result derived independently
   from the implementation, then run it. Confirm it fails for the missing
   behavior, not a setup error.
3. Implement one small change that makes that test pass. Work in vertical slices:
   one behavior, one test, one production change before starting another behavior.
   Rerun the focused test to confirm the pass, then the required checks.
4. Refactor only while tests stay green.

Do not test private implementation details, duplicate the production algorithm
in the assertion, or mock collaborators merely to verify internal calls. Prefer
real public behavior and test doubles only at an external, slow, nondeterministic,
or costly boundary. A useful test should survive an internal refactor and fail
when its observable contract regresses.

Do not force TDD for documentation, declarative configuration, copy, or a pure
visual adjustment. Do not add a test framework for a small change. Instead run
the strongest existing direct verification and state the coverage gap. Never
delete or rewrite pre-existing work to manufacture RED; add a characterization
or regression test and disclose the limit when behavior already exists.
