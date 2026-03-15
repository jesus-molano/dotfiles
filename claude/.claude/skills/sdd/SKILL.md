---
name: sdd
description: Specification-Driven Development workflow for a feature. Six phases with automated spec generation, review gate, implementation, and verification
disable-model-invocation: true
argument-hint: "<feature description>"
---

Specification-Driven Development workflow for: $ARGUMENTS

Execute this six-phase workflow. STOP after the Review phase and wait for user approval before continuing.

---

## Phase 1 — Explore

Use an Explore agent to scan the codebase:
- Identify existing patterns, components, and conventions relevant to the feature
- Find reusable utilities, composables, hooks, or services
- Map the project structure and tech stack
- Note file paths of similar features for reference

## Phase 2 — Spec

Create the spec directory `docs/sdd/<feature-slug>/` with these files:

### requirements.md
- User stories with acceptance criteria
- Constraints and edge cases
- Non-functional requirements (performance, a11y)
- No TBDs or ambiguity — every requirement must be testable

### design.md
- Architecture decisions and rationale
- Component hierarchy (each component < 150 lines)
- Data flow and state management
- API contracts (if applicable)
- Reference existing patterns by file path

### tasks.md
- Implementation checklist ordered by dependency
- Each task independently implementable
- Size each task (S/M/L)
- Include file paths for each task

### status.yaml
```yaml
feature: <feature-slug>
phase: spec
started_at: <today's ISO date>
ticket_id: null
```

Use Context7 MCP for framework-specific documentation before writing specs.

## Phase 3 — Review

Present a summary of the spec:
- Feature overview (2-3 sentences)
- Component list with responsibilities
- Task count and estimated complexity
- Key design decisions that need validation

**STOP HERE. Wait for user approval before proceeding to Phase 4.**

Update `status.yaml` phase to `review`.

## Phase 4 — Implement

After user approval:
- Execute tasks from `tasks.md` in dependency order
- Follow the design from `design.md` strictly
- TypeScript strict, no `any`
- Feature-based structure, no atomic design
- Components < 150 lines — split if exceeded
- Update `status.yaml` phase to `implement`

## Phase 5 — Verify

Run verification against the spec:
- Check every requirement in `requirements.md` is implemented
- Validate design compliance with `design.md`
- Confirm all tasks in `tasks.md` are complete
- Run type checker (`vue-tsc --noEmit` or `tsc --noEmit`)
- Run tests if they exist
- Create `docs/sdd/<feature-slug>/verification.md` with:
  - Requirements checklist (PASS/FAIL per item)
  - Design compliance notes
  - Task completion status
  - Issues found
  - Verdict: PASS | PARTIAL | FAIL
- Update `status.yaml` phase to `verify`

## Phase 6 — Report

Present final results:
- Verification verdict
- Files created/modified
- Any remaining issues or follow-ups
- Update `status.yaml` phase to `done`
