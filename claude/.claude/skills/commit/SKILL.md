---
name: commit
description: Create a conventional commit without AI attribution
disable-model-invocation: true
arguments:
  - name: message
    description: Optional commit message (auto-generated if omitted)
---

# Git Commit

## Rules
- NEVER add "Co-Authored-By", AI attribution, or generated-by footers
- Conventional commit format: type(scope): description
- Imperative mood, <72 chars for first line
- Stage individual files — NEVER `git add .` or `git add -A`

## Steps

1. Check status:
   ```bash
   git status --short
   git diff --cached --stat
   ```

2. If nothing staged, identify changed files and stage specific files:
   ```bash
   git diff --name-only
   ```
   Stage individual files — NEVER `git add .` or `git add -A`.

3. Generate or use provided commit message:
   - Analyze the staged diff to determine type and scope
   - Write concise description in imperative mood
   - Add body only if the change needs explanation (WHY, not WHAT)

4. Commit:
   ```bash
   git commit -m "type(scope): description"
   ```
   Or with body:
   ```bash
   git commit -m "type(scope): description" -m "Body explaining why this change was made."
   ```

5. Verify:
   ```bash
   git log -1 --format="%h %s"
   ```
   Confirm: no Co-Authored-By, no AI attribution, clean conventional commit.

## Examples
```
feat(auth): add login form validation
fix(products): resolve race condition in useProducts composable
refactor(cart): extract price calculation to shared util
docs(readme): add deployment instructions
test(auth): add unit tests for useAuth hook
chore(deps): update nuxt to 4.1.0
perf(images): lazy load below-fold product images
```
