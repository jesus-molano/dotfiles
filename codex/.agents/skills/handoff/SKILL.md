---
name: handoff
description: Prepare a precise handoff for another engineer or agent so work can continue without rediscovery. Use when pausing, delegating, or transferring ownership of an implementation or investigation.
---

# Handoff

Write a compact, evidence-backed continuation packet.

Include the objective and current status; decisions and rationale; files and relevant paths; completed work; exact validation run and outcomes; remaining steps in order; blockers and open questions; risks, rollback, and external state changes. Separate verified facts from assumptions. Point to durable artifacts rather than pasting long logs, and omit all secrets or environment-file contents.

The recipient should be able to start at the next safe action. Do not claim ownership transfer, publish changes, or update external systems unless authorized.
Return the packet in the response unless the user requests a specific durable
file or destination.
