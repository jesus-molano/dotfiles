---
name: verification-before-completion
description: Select and run fresh, proportionate verification before claiming a change is complete, fixed or ready to commit, including when no automated test exists. Scale the checks to the risk of the change.
---

# Verification Before Completion

1. Inspect the final diff and identify the claim being made.
   For added or replaced UI/behavior, check the reuse decision against actual
   shared implementations and consumers. Resolve unexplained duplicates or
   bypassed components; a correct screenshot or passing build alone does not
   establish reuse. If prior evidence is missing, perform a bounded repository
   search before declaring completion.
2. Run the smallest fresh command or observation that proves each changed
   behavior, then repository-mandated checks. Read exit status and relevant
   output; never claim a pass from a run on an older tree or in another session.
   Keep verification proportionate. Skip a re-run only when you saw that
   check's output for the current tree in this session; cite that output.
   A hook or gate that printed nothing gives no result to cite.
   - After a follow-up edit (a correction, a review fix, a test tweak), rerun
     only the checks that cover the edited files: their unit tests or e2e spec,
     lint and typecheck of those files, and one browser look for UI. Cite the
     earlier passing runs for the rest.
   - Run the full suites, the build and every e2e spec once, before the last
     commit or the handoff of the task, not after every edit.
   - To learn whether a failure already exists on the base branch, cite the
     base CI or use a separate worktree. Never `git stash` the user's working
     tree for it; if neither is cheap, report the failure as unverified.
3. For web changes, invoke `verify-web-change` for the focused web checklist.
4. Run `git diff --check` and confirm unrelated files were not changed.
5. Report exactly what ran: commands, results, exclusions, and remaining
   uncertainty. If a check cannot run, say why and do not imply success.
   Include the reused/adapted paths or the concrete reason new code was needed.

Fresh verification supports a local commit only when repository instructions
allow it. Publication requires its independent safety gate and authorization.
