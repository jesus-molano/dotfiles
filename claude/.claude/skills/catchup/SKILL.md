---
name: catchup
description: Load context from current git branch changes to resume work quickly
disable-model-invocation: true
context: fork
agent: Explore
---

# Catch Up

Bootstrap session context by reading what changed on the current branch.

## Steps

1. Identify the base branch:
   ```bash
   git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD
   ```

2. Get all changed files relative to base:
   ```bash
   git diff --name-status main...HEAD
   ```

3. Read the diff summary:
   ```bash
   git diff --stat main...HEAD
   ```

4. Read the commit history on this branch:
   ```bash
   git log --oneline --no-decorate main..HEAD
   ```

5. If a handoff file exists (`docs/session-state.md`), read it and report its contents.

6. Skim the changed files to understand what was done and what's in progress.

## Output

Provide a concise summary:
- **Branch**: name and how many commits ahead
- **What was done**: grouped by feature/area
- **Files touched**: key files, not exhaustive list
- **Handoff notes**: if session-state.md exists
- **Likely next step**: based on the state of the code
