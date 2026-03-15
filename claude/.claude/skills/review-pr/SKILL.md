---
name: review-pr
description: Review a pull request for code quality, security, performance, and accessibility
context: fork
agent: code-reviewer
argument-hint: "[pr-number-or-branch]"
arguments:
  - name: pr
    description: PR number or branch name (defaults to current branch)
---

# PR Code Review

## Steps

1. Get the PR diff:
   ```bash
   gh pr diff ${pr:-$(git branch --show-current)} --color=never
   ```
   If no PR number given, use current branch.

2. Get PR metadata:
   ```bash
   gh pr view ${pr:-$(git branch --show-current)} --json title,body,files,additions,deletions
   ```

3. Read the review checklist from `${CLAUDE_SKILL_DIR}/REFERENCE.md`
4. Review the diff against each checklist category.

## Output Format

### Critical 🔴
Issues that must be fixed before merge.
Format: `file:line — description`

### Warnings 🟡
Issues that should be addressed.
Format: `file:line — description`

### Suggestions 🔵
Nice-to-have improvements.
Format: `file:line — description`

### Positives 🟢
Good patterns worth noting.
Format: brief description
