---
name: lint
description: Detect the project's linter and run it with auto-fix
disable-model-invocation: true
allowed-tools: Bash, Read, Glob
---

Detect the project's linter and run it with auto-fix.

1. Check the project root for linter configs in this priority order:
   - `biome.json` or `biome.jsonc` → run `pnpm biome check --write .`
   - `.eslintrc*` or `eslint.config.*` → run `pnpm eslint --fix .`
   - `prettier` key in package.json or `.prettierrc*` → run `pnpm prettier --write .`
2. If no linter config is found, tell the user no linter is configured
3. Report only errors and warnings — suppress clean file output
4. Auto-detect the package manager from the lockfile before running
