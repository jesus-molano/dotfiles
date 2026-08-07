---
name: spec-and-standards-review
description: Review a change or proposal against its specification and applicable engineering standards, with evidence-based findings. Use for pre-merge, design, or compliance-oriented reviews.
---

# Spec and Standards Review

Review without modifying the target.

1. Fix the review range before judging it: base commit plus all committed,
   staged, unstaged, and relevant untracked changes in scope. Record exclusions.
2. When custom agents are available, dispatch `reviewer-spec` and
   `reviewer-standards` in parallel with the same range and evidence. Otherwise,
   perform two independent passes and disclose the fallback.
3. The spec pass builds a traceability table: requirement, evidence location,
   status, and consequence. It marks specification gaps separately from
   implementation defects.
4. The standards pass checks observable behavior first, then safety,
   compatibility, accessibility, performance, reliability, and test coverage as
   applicable. Do not infer an unstated standard.
5. Merge and deduplicate findings without weakening either axis. Classify by
   severity and confidence; every finding needs a concrete scenario,
   file/location, violated requirement or standard, and remediation direction.

Report no finding when the evidence supports conformance. Avoid style-only comments and avoid reproducing sensitive data.
