---
name: handoff
description: Save session state to docs/session-state.md before clearing context
disable-model-invocation: true
---

# Handoff

Save current session state so the next session can resume without losing context.

## Steps

1. Create `docs/` directory if it doesn't exist.

2. Write `docs/session-state.md` with this exact format:
   ```
   # Session State

   ## Task
   One-line description of what we're working on.

   ## Done
   - Completed item 1
   - Completed item 2

   ## Pending
   - [ ] Next step 1
   - [ ] Next step 2

   ## Key Files
   - path/to/file1
   - path/to/file2
   ```

3. Write `docs/project-status.yaml` with structured tracking:
   ```yaml
   project: {name from package.json or directory}
   updated: {YYYY-MM-DD HH:MM}
   branch: {current git branch}

   phase:
     current: "{current phase or task area}"
     completed:
       - "{completed phase 1}"

   task:
     summary: "{one-line current task}"
     status: "{in-progress|blocked|review}"

   artifacts:
     - "{path}: {brief description}"

   decisions:
     - "{key decision made this session}"

   next:
     - "{next step 1}"
     - "{next step 2}"
   ```

4. Add both files to `.gitignore` if not already present.

5. Verify the files were written:
   ```bash
   wc -l docs/session-state.md docs/project-status.yaml
   ```

## Rules
- session-state.md: Hard limit **30 lines max**. No code snippets, no explanations.
- project-status.yaml: Hard limit **35 lines**. Valid YAML.
- Only task name, completed items (1 line each), pending items, key file paths.
- If files already exist, overwrite them.
- Do NOT commit these files — they're ephemeral.
