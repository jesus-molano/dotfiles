# Status and full initialization

Run `tessera.py status --repo PROJECT` before an implementation choice. It is
local, offline and read-only. It returns the status, `next_action`, reasons,
revision, paths, inventory hash, counts and pending, protected or deleted files.

| Status | Meaning | Next step |
|---|---|---|
| `uninitialized` | No inventory or catalog | Ordinary reuse search; `init` only when the user asks |
| `initializing` | Inventory exists; review or finalization incomplete | Resume pending files |
| `needs_update` | A finalized catalog or its inventory changed | `changes`, `scan`, review the delta, `finalize` |
| `needs_full_review` | Old catalog without inventory, incompatible policy or missing baseline | `init` or `scan --full`, as `next_action` says |
| `ready` | Inventory reviewed, catalog validated, both current | `index` and `card`; `prepare --require-ready` for a provider decision |
| `blocked` | Uncommitted changes, unreadable inventory or invalid location | Fix the cause and keep the data |

`curate_catalog` and `resolve_checkout_changes` are agent actions, not
commands. `ready` proves coverage of the reviewed Git tree, not decision
quality, passing tests or enough provider capacity. Large catalogs are
evaluated through [exhaustive batches](batching.md); every card stays whole, and
an indivisible card that is too large is an explicit error.

## First pass and resume

1. `init --repo PROJECT` writes `inventory.json` in the external namespace from
   `locate`. It keeps an existing catalog and is idempotent. Work on a clean
   checkout; never commit other people's changes, reset or pull to clear the
   state, and never edit the project's `.gitignore` to install Tessera.
2. The inventory holds **every file in the Git tree except tests and their
   artifacts**, with no filter by language, UI folder or task relevance.
   Untracked, non-ignored files block the capture; ignored files are not part
   of coverage. Secrets recognizable by path, links and submodules are
   `protected`: their content is never opened. A submodule is catalogued as its
   own project; do not claim coverage of its content or of a link target. Path
   protection is conservative and does not detect every secret by content.
   Respect the private paths in the project instructions as well: exclude them
   with that reason without opening them.
3. Optional but recommended: `skeleton --repo PROJECT` writes starting evidence
   to `curation/` in the external store: candidate sources, exports, the first
   real non-test usage by tag, import, `import()`, `require()` or `src=`, Nuxt,
   Vite, Vue CLI or Next conventions and hints about minified code. It reads Git
   objects of the revision and never opens tests or protected paths. It is
   evidence, not a catalog: it creates no cards and records no review, and its
   usages are first matches only. The agent reads each source and consumer
   before writing contracts.
4. Inspect all pending files in resumable batches. Delegate independent areas
   to `catalog-writer` (read-only drafts) or `reuse-scout` (evidence gaps); the
   main agent validates and writes. Classify each file as `catalogued`,
   `supporting` or `excluded` with a concrete reason. Exclude documentation,
   dependencies or generated code for their verified nature, never for
   irrelevance to the current task.
5. Create or extend `catalog.json`, with a prior copy in `history/`. Read
   contracts, exports and non-test consumers; group a file's reusable exports
   into its card. Never invent usages: `usages: []` needs a `usage_gap` that
   explains the search or the framework's implicit use. Omit the `tests` field.
   Keep `scope` consistent with every catalogued source.
6. Record each batch with `review --repo PROJECT --batch EXTERNAL_BATCH.json`,
   using `revision` and `inventory_sha256` from a recent `status`. The batch
   writes no cards and does not prove the agent read them: it records the review.
7. With zero pending files, run `finalize --repo PROJECT`. It validates the
   catalog, its revision, the match with the classified sources and their
   evidence. Only then can `ready` appear. If it fails, fix the cause and resume.

Batch example (revisions and paths must come from the real project):

```json
{
  "schema": 1,
  "revision": "OID_FROM_STATUS",
  "inventory_sha256": "HASH_FROM_STATUS",
  "files": [
    {"path": "src/format.ts", "kind": "catalogued", "reason": "Contract and consumers reviewed"},
    {"path": "README.md", "kind": "excluded", "reason": "Documentation without reusable implementation"}
  ]
}
```

## Test exclusion before reading

The helper applies `is_test_path` to the name before opening any content. It
skips the folders `test`, `tests`, `spec`, `specs`, `__tests__`, `e2e`,
`cypress`, `__fixtures__`, `__mocks__`, `__snapshots__`, `test-results`,
`playwright-report`, `coverage`, `.pytest_cache` and `.nyc_output`; the names
`test_...`, `test-...`, `*.test.*`, `*.spec.*`, `*_test.*` and their dash or dot
variants, plus `*Test.java`, `*Tests.java`, Kotlin and C#. It also skips
`conftest.py` and `vitest`/`jest`/`playwright`/`cypress` files with `.config.*`
or `.setup.*` suffixes. It never analyzes content to decide whether a file is a
test. If the project declares another convention, identify it by path and
extend the predicate before inspecting those files.

Tests never appear in pending files, sources, consumers or supporting evidence.
Do not read them by hand or delegate their analysis. `ready` covers only the
tree this policy includes. Commits that touch only tests do not invalidate the
catalog; a clean checkout is still required.

Policy 2 migrates policy-1 inventories with `scan`: it keeps a copy in
`history`, removes tests by path and keeps the other classifications only when
their Git object and mode did not change. It requires a new `finalize` without
repeating valid review. Do not use `scan --full` for this compatible migration.
Old `tests` fields are accepted but ignored without resolving their paths and
are removed from the provider context; remove them with a prior copy when you
curate. A test reference in `source`, `usages` or `supporting_files` is
rejected: remove it and review the real contract or consumer. Keep historical
runs and prepare a new one; never rewrite old evidence.

## Card kind and agent responsibility

A card's `kind` describes its nature; it differs from the file classification
in the inventory. It is extensible text, not inferred from the name:

- `component`: UI and its contract of props, events, slots or composition.
- `hook` / `composable`: framework state, reactivity or lifecycle.
- `utility`: reusable operation with explicit inputs, outputs and effects.
- `page`: screen or route; also review its reusable exports and behavior.
- `service`: API access, persistence or other shared operations.
- Other types or mixed modules: describe every relevant export without forcing
  a wrong category. Use `name`, `tags`, contract and constraints to tell them
  apart. Location and name are hints; check code and consumers.

An ambiguous piece stays pending. `excluded` needs a verifiable reason, not
"not needed now". The system proves file accounting and freshness; the semantic
quality of the classification depends on the agent's inspection.

## Maintenance

`scan` compares the whole current tree and keeps reviews only when the file's
Git object and mode match. Additions, changes and renames need review; deletions
are reconciled with the catalog. `changes` adds the affected cards and evidence.
Review dependents when a contract changes. Update `reviewed_revision` after the
inspection, not to silence a warning. Finalize again before a decision. After
implementing and verifying, repeat the update on the committed revision.

`scan --full` invalidates previous classifications with a backup and keeps the
cards. Use it for an incompatible policy, a lost baseline or a requested full
review, not on every task or merely because time passed. Switching branch or
worktree compares the corresponding tree and does not repeat unchanged work.

Writes use `inventory.lock`, a private backup and an atomic replace. A stale
batch is rejected. If a lock remains after an interruption, check that no other
process runs and apply the project rules before removing it; never delete it
automatically. There is no watcher, fetch, pull or provider call.

Old manual flows may use `prepare` without `--require-ready`, but the manifest
then says `project_status: not_checked` and proves no complete coverage. The
normal flow requires the option. `evaluate` checks it again before the network.
