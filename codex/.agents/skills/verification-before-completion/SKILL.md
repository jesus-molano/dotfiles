---
name: verification-before-completion
description: Select and run fresh, proportionate verification before claiming a change is complete, fixed, or ready to commit. Use after an implementation or fix, including when no automated test exists.
---

# Verification Before Completion

1. Inspect the final diff and identify the claim being made.
2. Run the smallest fresh command or observation that proves each changed
   behavior, then repository-mandated checks. Read exit status and relevant
   output; never claim a pass from an earlier run.
3. For web changes, invoke `$verify-web-change` for the focused web checklist.
4. Run `git diff --check` and confirm unrelated files were not changed.
5. Report commands, results, exclusions, and remaining uncertainty. If a check
   cannot run, say why and do not imply success.

Fresh verification supports a local commit only when repository instructions
allow it. Publication requires its independent safety gate and authorization.
