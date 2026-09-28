# Prompt to update the work PC

Use after the commit of this delivery has been published and verified in
`git@github.com:jesus-molano/dotfiles.git`. The delivery message gives the
published OID and branch. This document prepares the update; it does not prove
a push and does not replace the checks on the receiving machine.

Copy this prompt and add the OID and branch from the publication message:

```text
We are on my work computer, not the machine where this change was prepared.
Update my local checkout of jesus-molano/dotfiles to the published revision
given with this prompt and deploy the shared AI configuration. Do the checks
yourself and record what is still pending; do not just give me instructions.

First read AGENTS.md, docs/ai.md and ai/skills/tessera/SKILL.md from the
checkout. Check OS, Git state, remote, branch and the published revision. Keep
my local changes and fast-forward when possible; never reset, delete or
overwrite changes to resolve a divergence. Do not assume paths, GPU, RAM,
credentials or installed clients match the home computer.

Deploy with the existing tooling. On native Windows review and run
scripts/ai-setup.ps1 in plan, apply and check modes; choose Claude or both
clients depending on what is installed. Keep models, effort, memory, accounts,
plugins and local preferences. If the sync reports a conflict, inspect it and
keep its backup; never delete other copies to get past it.

Run the Python regressions with PYTHONDONTWRITEBYTECODE=1 through unittest
discover on scripts/tests (test_tessera*.py, test_kev_local.py, test_ai_sync.py,
test_ai_guard.py). Confirm the deployment excludes __pycache__, .pyc and .pyo.

Tessera: catalogs stay in LOCALAPPDATA outside every repository. Do not create
.tessera, change .gitignore or copy cards, history or evidence to dotfiles or
GitHub. For each existing catalog run status and, when it is not ready, changes;
refresh the affected cards and finalize. Check that index and card work. Do
not initialize new projects unless I ask. Provider decisions (Jev or Kev) are
now optional and explicit: do not run evaluate as part of this update. Do not
grant provider consent yourself; tell me which projects would need
"tessera.py consent" and I will decide after confirming the company allows it.

Kev is already installed here: locate its runtime and run the check of
ai/skills/tessera/scripts/kev-local.py. Do not repeat install or windows-cuda on
a working runtime, download another model or change drivers.

Open a new Claude Code session and confirm with /memory, /skills, /agents,
/hooks, /permissions and /mcp that the rules, skills, six roles, the ai-guard
hook, the deny rules and the status line are active. In Code in Desktop enable
bypass permissions only if company policy allows it.

Finish with the installed OID, deployed clients and skills, test results, the
catalogs checked, the Kev runtime state, the backup path to revert the
configuration and any concrete blocker. Do not publish further changes.
```
