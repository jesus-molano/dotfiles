---
name: handoff
description: Prepare precise continuation notes so another engineer or agent can resume work without rediscovery. Use when pausing, ending a session or handing over an implementation or investigation; it writes notes only and moves no chats, worktrees or ownership.
---

# Handoff Notes

Write a compact, evidence-backed continuation packet. If the implementation
already has a task record, use and link it; do not create a competing plan.
Keep the selected reuse contracts, candidate paths and any verification still
needed on resume.

Lead with the objective, scope, authority limits, current status and
definition of done. Include decisions and rationale; relevant files and paths;
completed work; the exact checks run and their results; remaining steps in
order; blockers and open questions; risks, rollback and external state changes.
When Linear is in scope, include only verified issue IDs or links, their current
status and any tracker action that still needs authorization. Separate
verified facts from assumptions. Point to canonical artifacts instead of
pasting long logs, and omit all secrets and environment-file contents.

The reader must be able to start at the next safe action. These are notes only:
do not move chats, change worktrees or terminals, claim an ownership transfer,
publish changes or update external systems. Return the packet in the response
unless the user asks for a specific file and authorizes that write.
