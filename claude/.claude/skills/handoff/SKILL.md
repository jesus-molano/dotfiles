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

3. Verify the file was written:
   ```bash
   wc -l docs/session-state.md
   ```

## Rules
- Hard limit: **30 lines max**. No code snippets, no explanations.
- Only task name, completed items (1 line each), pending items, key file paths.
- If `docs/session-state.md` already exists, overwrite it.
- Do NOT commit this file — it's ephemeral.
