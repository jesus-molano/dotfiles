---
name: handoff
description: Prepare precise continuation notes for another engineer or agent so work can resume without rediscovery. Use when pausing or documenting the transfer context of an implementation or investigation; this skill does not move chats, worktrees, terminals, or ownership.
---

# Handoff Notes

Write a compact, evidence-backed continuation packet.

Lead with the objective, scope, authority boundaries, current status, and
definition of done. Include decisions and rationale; files and relevant paths;
completed work; exact validation run and outcomes; remaining steps in order;
blockers and open questions; risks, rollback, and external state changes.
When Linear is in scope, include only verified issue IDs or links and their
current status, plus any proposed tracker action that still needs authorization.
Separate verified facts from assumptions and questions. Point to canonical
artifacts rather than pasting long logs, and omit all secrets or environment-file
contents.

The recipient should be able to start at the next safe action. These are notes
only: do not move an Orca/Codex chat, change worktrees or terminals, claim
ownership transfer, publish changes, or update external systems. Return the
packet in the response unless the user requests a specific durable file or
destination and authorizes that write.
