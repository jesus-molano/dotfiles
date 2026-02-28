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

1. Check for structured status file:
   ```bash
   [[ -f docs/project-status.yaml ]] && cat docs/project-status.yaml
   ```
   If it exists, report: current phase, task status, decisions, and next steps.

2. Check for session state markdown:
   ```bash
   [[ -f docs/session-state.md ]] && cat docs/session-state.md
   ```

3. Identify the base branch:
   ```bash
   git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD
   ```

4. Get all changed files relative to base:
   ```bash
   git diff --name-status main...HEAD
   ```

5. Read the diff summary:
   ```bash
   git diff --stat main...HEAD
   ```

6. Read the commit history on this branch:
   ```bash
   git log --oneline --no-decorate main..HEAD
   ```

7. Skim the changed files to understand what was done and what's in progress.

## Output

Provide a concise summary:
- **Phase**: current phase and completed phases (from project-status.yaml)
- **Task**: current task and status
- **Decisions**: key decisions made (from project-status.yaml)
- **Branch**: name and how many commits ahead
- **What was done**: grouped by feature/area
- **Files touched**: key files, not exhaustive list
- **Handoff notes**: if session-state.md exists
- **Likely next step**: based on the state of the code
