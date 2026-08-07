---
name: linear-workflow
description: Read Linear context and, with explicit authorization, create or update issues, comments, and workflow fields through the official Linear MCP. Use when work must be associated with Linear through the local safety workflow rather than another Linear integration.
---

# Linear Workflow

Use the official Linear MCP as the tracker boundary. The normal `linear` server
must use the `/mcp/readonly` endpoint. A separate `linear-write` server may use
`/mcp`, but it must remain disabled in the base configuration and be enabled only
for an explicitly authorized publication session. Confirm that the intended
workspace, team, project, and issue identifiers are known. If the required MCP
is unavailable, stop at a local draft or explain the missing setup; do not
silently edit Codex configuration.

## Safety contract

- Read and search first. Treat issue, team, project, label, cycle, status, and
  user names as live data rather than inventing them.
- Before any external write, show the exact target objects and proposed fields,
  explain the grouping of a batch, and ask for explicit confirmation
  immediately before the calls. A general request to manage Linear is not
  authorization for a later concrete mutation.
- Authorization never crosses sessions. A read-only session may prepare a
  preview, but the write-enabled session must re-read the targets, reconcile
  concurrent changes, show a fresh preview, and obtain fresh confirmation.
- A write may run only when `linear-write` was explicitly enabled for the
  current session after that preview. Never change the persistent MCP state from
  this skill. A normal session must remain technically read-only.
- Creation, field or status updates, assignments, comments, label creation,
  archiving, and deletion are external mutations. Approval for one does not
  authorize another, nor does it authorize commit, push, PR, deploy, or apply.
- Search for stable duplicates before creating issues. On a partial failure,
  report the successful IDs and retry only the missing operations.
- Re-read affected issues after a mutation. Never overwrite a concurrent change
  silently, and prefer reversible edits or archiving over deletion.
- Never place OAuth tokens, secrets, or environment-file contents in a ticket,
  command, diff, log, or summary.

## Workflow

1. Clarify the requested outcome and whether it is read-only or mutating.
2. Resolve the workspace, team key, project, issue IDs, statuses, labels,
   assignees, cycle, priority, and dates that the operation actually needs.
3. Read the relevant Linear objects and distinguish verified fields from
   assumptions or missing decisions.
4. If the current session lacks `linear-write`, return an unapproved draft
   preview with object count, identifiers, intended fields, omissions, and
   duplicate handling for a new write-enabled session. Do not request or claim
   final authorization yet.
5. In the write-enabled session, re-read the targets, reconcile changes, show
   the updated preview, and obtain confirmation immediately before the calls.
6. Execute only that freshly approved batch and verify the resulting objects by
   ID.
7. Report IDs or links, what changed, what did not, partial failures, and the
   safest next action or rollback.

## Engineering integration

- `$to-tickets` owns decomposition and produces local drafts first. Publish an
  approved batch only through this skill after its Linear mapping is explicit.
- `$implement-ticket` may use a Linear key or URL as read-only input. Code being
  implemented, validated, committed, pushed, or merged never implies permission
  to change the issue status or add a comment.
- `$handoff` may include verified Linear IDs, links, status, and pending tracker
  actions. It remains notes-only unless a separate Linear write is authorized.
- Use an issue key in a branch name or PR title only when the repository
  workflow calls for it. Creating the branch or PR remains a separate action.

Enable the preconfigured write server for one new session only with:

```bash
codex -c 'mcp_servers.linear-write.enabled=true'
```

The override does not persist. The opening prompt must explicitly invoke
`$linear-workflow` and carry the draft preview, but not claim that a prior
session's authorization remains valid.

This local adaptation is based on an official OpenAI skill. See
[source and modification notice](SOURCE.md) and the bundled
[Apache-2.0 license](LICENSE.txt).
