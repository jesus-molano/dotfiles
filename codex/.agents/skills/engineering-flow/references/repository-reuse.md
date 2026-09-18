# Repository reuse

Apply before adding or replacing UI or behavior, regardless of task size. The
goal is to use the repository's supported solution, not merely make new code
look similar. Reuse inspected earlier in the same task remains valid unless
requirements, contracts, or the relevant code changed.

Delegate candidate discovery to `reuse-scout` (gpt-5.6-luna, low effort,
read-only). Give it the repository, requested behavior, relevant platform and
known owner paths, not the whole conversation. If the role is unavailable,
request the same model/effort explicitly on a fresh subagent. One bounded search
returns candidate paths, public contracts, real consumers and evidence gaps.
Escalate only an unresolved search question to gpt-5.6-terra; do not repeat
the scout's exploration with the main agent. The implementing agent owns
the final compatibility decision and reads only the necessary candidate code.
Existing current evidence needs no new scout. If lightweight delegation is
unavailable, disclose it and perform only the minimum local inspection needed;
never silently claim a model switch or skip the reuse check.

1. Locate the owning feature and its nearest working equivalent. Use `rg` and
   the repository's indexes, exports, aliases, component docs or stories to find
   candidates by behavior as well as name. Inspect shared packages and the
   project's wrapper around a library, not only the current folder or the
   dependency list. Keep the search bounded to plausible owners and consumers.
2. Read the best candidate's implementation or public contract and a real call
   site. Check supported props, variants, slots, state, accessibility, and
   platform/runtime compatibility. For functionality, inspect existing hooks,
   services, helpers, validation and generated clients before adding equivalent
   logic. A search hit or matching name alone does not establish suitability.
3. Choose `reuse`, `extend`, `compose`, `extract-and-reuse`, `create`, or
   `not-applicable`. Briefly name the candidate path and the reason. For `create`,
   give the nearest rejected candidate and concrete missing capability, or the
   searched locations when no candidate exists. An incomplete search is an
   evidence gap, not proof of absence. For `not-applicable`, explain why the
   change adds or replaces no reusable behavior or UI.
4. Implement through the supported interface. Prefer existing props, slots and
   tokens over overrides, copies, or a new wrapper that only renames the API.
   Extend a shared contract only when necessary and inspect affected consumers;
   do not spread a task-local requirement to every caller. Do not force an
   incompatible or deprecated abstraction just to claim reuse.
5. Recheck the final diff for duplicate behavior, bypassed wrappers, copied CSS,
   hardcoded design values, and unexplained new primitives. Verify the selected
   component's behavior in the changed flow, not only the import or appearance.

For UI, explicitly look for the repository's modal/dialog, typography/text,
buttons, fields, notifications, layout and token conventions relevant to the
request. A styled `div` is not an equivalent replacement for a supported dialog
with focus management. A styled paragraph must not bypass a suitable typography
component. Native HTML is appropriate when it is the established pattern or no
compatible abstraction exists; preserve semantics and explain the decision.

Include one concise reuse line with paths in the final handoff. Delegated writers
receive the chosen contract and evidence, or this inspection as part of their
scope. Escalate to `frontend-task` only when its existing complexity criteria
apply; do not prepare a second Atlas task for a decision it already owns.
