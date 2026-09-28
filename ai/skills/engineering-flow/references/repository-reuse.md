# Repository reuse

Apply before adding or replacing UI or behavior, regardless of task size. The
goal is to use the repository's supported solution, not to make new code look
similar. Reuse evidence gathered earlier in the task stays valid unless the
requirements, contracts or relevant code changed.

## Find candidates

- **Tessera catalog, when the project has one.** Run
  `tessera.py status --repo PROJECT` (read-only, no network). If the status is
  `ready` or `needs_update`, run `tessera.py index --repo PROJECT` for the
  compact list and `tessera.py card --repo PROJECT --id ID` for the few cards
  that matter. Refresh stale cards as the `tessera` skill describes. Never read
  the whole catalog into context, and never start initialization (`init`)
  unless the user asks for it: an uninitialized project uses the search below.
- **Search.** Otherwise, or to fill a gap, delegate one bounded search to
  `reuse-scout` (light model, read-only). Give it the repository, the requested
  behavior, the platform and known owner paths, not the whole conversation. It
  returns candidate paths, contracts, real consumers and evidence gaps. If
  delegation is unavailable, say so and do the minimum local inspection; never
  claim a model switch that did not happen.

## Decide

1. Locate the owning feature and its nearest working equivalent. Search by
   behavior as well as name: indexes, exports, aliases, component docs or
   stories, shared packages and the project's wrappers around libraries, not
   only the current folder or the dependency list.
2. Read the best candidate's implementation or public contract and one real
   call site. Check supported props, variants, slots, state, accessibility and
   platform compatibility. For functionality, check existing hooks, services,
   helpers, validation and generated clients. A name match alone proves nothing.
3. Record one decision: `reuse`, `extend`, `compose`, `extract-and-reuse`,
   `create` or `not-applicable` (Tessera uses `reuse`, `modify`, `wrap`,
   `create`, `insufficient_evidence`). Name the candidate path and the reason.
   For `create`, give the nearest rejected candidate and the missing capability,
   or the searched locations. An incomplete search is an evidence gap, not
   proof of absence.
4. Implement through the supported interface. Prefer existing props, slots and
   tokens over overrides, copies or a wrapper that only renames the API. Extend
   a shared contract only when necessary and check its consumers. Do not force
   an incompatible or deprecated abstraction just to claim reuse.
5. Recheck the final diff for duplicate behavior, bypassed wrappers, copied
   CSS, hardcoded design values and unexplained new primitives.

For UI, explicitly look for the project's dialog, typography, button, field,
notification, layout and token conventions. A styled `div` is not a
replacement for a supported dialog with focus management, and a styled
paragraph must not bypass a suitable typography component. Native HTML is right
when it is the established pattern or no compatible abstraction exists.

Put one reuse line with paths in the final handoff. Delegated writers receive
the chosen contract and evidence.
