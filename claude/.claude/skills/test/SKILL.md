---
name: test
description: Run the project's test suite with compact output
disable-model-invocation: true
argument-hint: "[file or pattern]"
allowed-tools: Bash, Read, Glob
---

Run the project's test suite with compact output.

1. Detect the test runner:
   - If `vitest` is in devDependencies → run `pnpm vitest run --reporter=dot`
   - If `jest` is in devDependencies → run `pnpm jest --verbose=false`
2. Auto-detect the package manager from the lockfile before running
3. If tests fail, summarize failures and suggest fixes
4. If a specific test file or pattern is provided as argument: $ARGUMENTS — scope the run to that target
