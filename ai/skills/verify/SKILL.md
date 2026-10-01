---
name: verify
description: Verify a change before committing it. Claude Code runs a skill with this name before each commit.
---

# Verify

Load `verification-before-completion` and follow it for the staged change.
Commit only after its checks pass, or state which check failed or could not
run.
