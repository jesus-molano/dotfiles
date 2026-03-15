---
name: typecheck
description: Run the project's TypeScript type checker
disable-model-invocation: true
allowed-tools: Bash, Read, Glob
---

Run the project's TypeScript type checker.

1. Detect the project type:
   - If `vue-tsc` is in devDependencies → run `pnpm vue-tsc --noEmit`
   - Otherwise → run `pnpm tsc --noEmit`
2. Auto-detect the package manager from the lockfile before running
3. Report errors concisely — group by file if possible
4. If there are errors, suggest fixes for each one
