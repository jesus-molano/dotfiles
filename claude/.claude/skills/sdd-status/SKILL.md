---
name: sdd-status
description: Scan all SDD workflows and report their status
disable-model-invocation: true
context: fork
agent: Explore
---

Scan all SDD workflows and report their status.

1. Search for all `docs/sdd/*/status.yaml` files in the project
2. For each one found, read the status.yaml and present a table:

| Feature | Phase | Started | Ticket | Progress |
|---------|-------|---------|--------|----------|

3. For progress, check `tasks.md` in the same directory and count completed vs total tasks (tasks marked with `[x]` vs `[ ]`)

4. If no `docs/sdd/` directory exists, report that no SDD workflows have been started

5. For any workflow not in `done` phase, offer to resume it from its current phase. Ask the user which workflow to continue if there are multiple in-progress ones.
