# AI clients: Claude Code and Codex

One neutral source in `ai/` configures Claude Code (CLI and the Code tab in
Desktop) and Codex. Each client keeps its own account, memory, history,
foreign connections and model/effort choice. `AGENTS.md` is each project's
contract. This setup does not turn normal chat or Cowork into a coding agent.

Design goals, in order:

1. **Safe by construction.** Hard limits are enforced by a hook and deny
   rules, not only by prose.
2. **No duplicated code.** Every UI or behavior change looks for the project's
   existing component, wrapper or utility first.
3. **Token-efficient.** Small always-loaded rules, compact skill descriptions,
   a light model for searches and reviews sized to the change.
4. **Reversible.** Every deployment is a transaction with a private backup,
   conflict detection and rollback.

## What is deployed

| Piece | Source | Claude Code | Codex |
|---|---|---|---|
| Global rules | `ai/rules/common.md` + `ai/adapters/<client>.md` + `ai/adapters/<platform>.md` | `~/.claude/CLAUDE.md` (generated) | `~/.codex/AGENTS.md` (generated, versioned) |
| Project rules | Each repository | `CLAUDE.md` and `AGENTS.md` (`claude-md-and-agents-md`) | `AGENTS.md` |
| Skills | `ai/skills/` (17 own + vendored `playwright-cli`) | `~/.claude/skills/` | `~/.agents/skills/` |
| Roles | `ai/roles/*.json` | `~/.claude/agents/*.md` | `~/.codex/agents/*.toml` |
| Hooks | `ai/hooks/*.py` | `~/.claude/hooks/` + `settings.json` | — |
| Settings | `scripts/sync-ai.py` | managed keys in `~/.claude/settings.json` | managed keys in `~/.codex/config.toml` |
| MCP | `scripts/sync-ai.py` | `~/.claude.json` | `config.toml` |

Linux links skills to the checkout; Windows copies them. Rules, roles and hooks
are regular files. Generated files carry a header: edit the source, never the copy.

### Claude settings managed by the sync

Only these keys and list entries are owned; everything else in the file is
kept, including foreign hooks, deny rules, models and projects.

| Setting | Value | Why |
|---|---|---|
| `language` | `spanish` | Replies in Spanish; config and skills are English. |
| `model` (default) | `opus` when absent | The main agent executes and reasons on Opus (Opus 5.5 today). Set only when missing and never owned, so a later `/model` or local choice is kept. |
| `permissions.defaultMode` | `auto` | A classifier approves routine actions and stops risky ones; no technical prompts. |
| `permissions.disableBypassPermissionsMode` | `disable` | Claude Code refuses `bypassPermissions`. That mode skips the classifier and the `soft_deny` rules. |
| `permissions.deny` (entries) | `.env*` read/edit, `~/.ssh`, `~/.gnupg`, `~/.aws`, Git and gh credentials, `~/.claude.json`, the Claude and Codex logins (`~/.claude/.credentials.json`, `~/.codex/auth.json`), `Edit` of Tessera `provider-consent.json` (also inside MSIX app stores) | Deny rules apply before the classifier; `Edit` rules cover every file write. `Read` and `Edit` rules also cover the shell commands Claude Code recognizes (`cat`, `head`, `tail`, `sed`, `tee`, redirections), but not indirect reads such as `grep -r` or scripts that open files. `ai-guard.py` blocks shell commands that name these files. |
| `hooks.PreToolUse` (entry) | `ai-guard.py` on `Bash`, `PowerShell`, `Monitor`, `Workflow`, `Write`, `Edit`, `MultiEdit` | Blocks the hard limits deterministically. |
| `hooks.UserPromptSubmit`, `hooks.UserPromptExpansion` (entries) | `ai-guard.py` (the second only for `workflow-authoring`) | Records the user's per-session workflow opt-in. See [Workflow opt-in](#workflow-opt-in). |
| `hooks.PostToolUse` (entry) | `project-gate.py format` on `Write`, `Edit`, `MultiEdit` | Formats the edited file in opted-in projects. See [Project gate](#project-gate). |
| `hooks.Stop` (entry) | `project-gate.py check` | Runs the project's fast checks before the turn ends, in opted-in projects. |
| `hooks.Stop` (entry, Linux) | `claude-notify` | Generic desktop notification at end of turn. |
| `sandbox.enabled`, `sandbox.autoAllowBashIfSandboxed`, `sandbox.allowUnsandboxedCommands` (Linux) | `true`, `false`, `true` | OS-level containment of every shell command. See [Sandbox](#sandbox). |
| `sandbox.filesystem.denyRead`, `sandbox.filesystem.denyWrite`, `sandbox.excludedCommands` (entries, Linux) | secret and credential paths; `~/.local/state/dotfiles/ai`; four `just` recipes | See [Sandbox](#sandbox). |
| `autoMode.soft_deny` (entries) | `$defaults` + the authority rules below | Teaches the classifier the authority rules. |
| `statusLine` | `statusline.py` | Model, project:branch, context %, 5h and 7d plan use. |
| `attribution.*` | empty / `false` | No co-author trailers or session links. |
| `pluginConfigs["agents-md@builtin"]` | `claude-md-and-agents-md` | Loads `AGENTS.md` next to `CLAUDE.md`. |
| `skillOverrides` | `user-invocable-only` for user skills, `name-only` for named skills | See [Skills](#skills). |

A managed entry that you remove by hand is reported as a conflict instead of
being silently re-added: put the entry back, or change the source in `ai/` or
`scripts/sync-ai.py` if you no longer want it. A key the sync adopts for the
first time never overwrites a different value you set yourself (for example
your own `statusLine`); the apply stops and names the key.

## Guardrails

`ai/hooks/ai-guard.py` runs before every shell command (`Bash`, `PowerShell` and
the background `Monitor` tool), every `Workflow` call and every file write or
edit, in Claude Code and in Codex (`~/.codex/hooks.json`, same schema and stdin
contract). Codex runs a new user hook only after you trust it once in its
`/hooks` view. It exits 2 (block) with a short reason, and never prints the
command, file contents or environment. It blocks only what is never part of a
normal task:

| Blocked | Rule it enforces |
|---|---|
| Every `git push` except the plain form `git push [-u \| --set-upstream] [remote] [branch \| HEAD:branch \| sha:refs/heads/branch]` as its own command (`git -C dir` and `--no-pager` are allowed). Blocked: other flags, `+ref`, `:ref`, several refspecs, `*` refspecs, tags (`refs/tags/`, version names such as `v1.0`, existing local tags, or any push in a command that also runs `git tag`), variables or `$(...)` in the push, pushes behind env assignments, wrappers, nested shells, substitutions or interpreter code, `GIT_CONFIG*`, `GIT_DIR`, `GIT_WORK_TREE` or `GIT_NAMESPACE` in the command, `git -c alias.*`, `git config alias.*` that pushes or runs `!` shell code, `git config` of `remote.*.mirror`, `remote.*.push`, `remote.*.pushurl`, `remote.*.receivepack`, `url.*.pushInsteadOf` or `push.*`, `git remote add --mirror`, `git remote set-url --push`, `git subtree push`, `git send-pack`, `git-push` binaries and `$var push` | Publish one verified ref, never rewrite or delete remote history. |
| The oh-my-zsh git aliases that push or wipe work (`gp`, `gpf`, `gpf!`, `gpod`, `gpoat`, `gpristine`, `ggpush`, `ggf`...) as commands; their names as arguments (`grep gpu`) or in here-doc text are allowed | The Claude Bash tool loads your zsh aliases; they hide the real command. |
| `gh repo delete`, `gh pr merge --admin`, `gh api -X DELETE`, `gh api` writes to `git/refs` or `git/tags`, and GraphQL `deleteRef`, `updateRef(s)` or `createRef` | Destructive publication is the user's. |
| `stow` with a glob of packages | Never run Stow over every directory. |
| `rm -r` of `/`, `~`, `$HOME`, `${HOME:?}` or the dotfiles checkout | No catastrophic deletion. |
| A command that names a secret file or credential store, except the harmless uses listed below the table: `.env*` in any form (globs such as `.env*`, `.en?` or `*.env` for `find -name` and `grep --include`, braces such as `.en{v,}`, `HEAD:.env`, `@.env`, `< .env`, inside strings or scripts), `~/.claude.json`, `~/.claude/.credentials.json`, `~/.codex/auth.json`, gh `hosts.yml`, `~/.git-credentials`, `~/.ssh` (except `*.pub`), `~/.gnupg`, `~/.aws`; also `op read`, `op inject`, `op item`, `op document`, `op run --no-masking`, `gh auth token`, `git credential fill` | Secrets only through `with-secrets`. |
| `tessera.py consent` and any write to `provider-consent.json` (redirections, copies, deletes, `sed -i`, inline scripts, PowerShell write cmdlets); reading or searching it is allowed | Only the user grants provider consent. |
| `Workflow` tool, unless the user opted in for this session | Multi-agent workflows only on request. See [Workflow opt-in](#workflow-opt-in). |
| Any shell command, `Write`, `Edit`, `MultiEdit` or `apply_patch` that names `workflow-grants` (reads too: interpreter code cannot be told apart from a write) | Only the user grants the workflow opt-in. |

Secrets and publication fail closed. The guard scans the raw command text for
them, independently of the parser, and every mention must lie inside a part of
the text that the parser understood as harmless:

- a plain push, as above;
- a file named in `echo`, `printf`, `touch`, `ls`, `stat`, `du`, `test`,
  `chmod` or `mkdir`, `git check-ignore` or `git rm --cached`, and here-doc
  text given to `cat` or `tee` (`cat >> .gitignore <<'EOF'`). This holds only
  when the output ends on the screen or in a file: piped on (`| python3`) or
  substituted (`$(echo ...)`), the text may become code, so it is not credited;
- a dotenv file written by a redirection, by a PowerShell write cmdlet or as
  the destination of `cp .env.example .env`. Credential stores are never
  written. Claude Code's own `Edit(**/.env)` deny rule still refuses recognized
  redirections into `.env`;
- an alias name used as an argument;
- comments, which never run;
- nested code (`bash -c`, `eval`, a here-doc read by a shell) that passed its
  own check and does not run a substitution's output.

Anything else blocks, including plain text: a commit message or PR body that
mentions `.env`, a credential store or `git push` must come from a file
(`git commit -F <file>`, `gh pr create --body-file <file>`). Templates (`*.example`, `*.template`, `*.sample`) and `*.pub`
keys are not secrets. An unparseable command that contains any of these
mentions, `push`, `rm`, `stow` or `consent` is blocked.

The other limits rely on the parser. It reads the command like the shell:
quotes, `$'...'` escapes, backslash-newline continuations, comments, `{ }`
groups, `if`/`then`/`do`, `case`, `!`, arithmetic, command and process
substitutions (also inside double quotes), here-docs (the body is data unless
the delimiter is unquoted or a shell reads it), here-strings, and text piped
from `echo` into a shell. It looks through env assignments, wrappers (`sudo`,
`env`, `nice`, `timeout`, `nohup`, `xargs`, `watch`, `with-secrets`...),
`find -exec`, `op run --` and nested shells (`bash -lc`, `sh -ec`, `eval`, up
to 8 levels). Because wrapper options are not all known, every later word after
a wrapper is also checked as a possible command. Redirections such as `2>&1` are
ignored, so `git push -u origin feat 2>&1` works. Showing the exact OID and
asking for authorization before publishing stays in the global rules.

Known limits: the guard is a safety net against mistakes, not a sandbox, and
code running as your user can still reach anything you can. On Linux the
[sandbox](#sandbox) closes the indirect reads for sandboxed commands. It does not expand
variables, brace-expanded command words or `xargs` input, and it does not read
files: `grep -r KEY .`, a script that opens `.env` without naming it on the
command line, and a script written in one command and run in the next all pass.
PowerShell has its own parser (quoting, `${...}` and `%USERPROFILE%` paths,
cmdlet aliases such as `ri`, `gc`, `rd /s`, `-Recurse:$true`, and nested
`cmd /c`, `pwsh -Command` and `Invoke-Expression`); there `gp` and `gpv` are
`Get-ItemProperty`. On Windows a command reported as Bash is checked with both
parsers, so Bash-only forms that mention a secret or a push (`if ... then`,
here-docs such as `cat >> .gitignore <<'EOF'`) are blocked there. The
`Read(**/.env.*)` deny rule also blocks `.env.example` templates,
in the Read tool and in the shell reads Claude Code recognizes, such as `cat`.

### Workflow opt-in

The `Workflow` tool runs only after the user asks for it in the same session.
`ai-guard.py` also runs on `UserPromptSubmit` and `UserPromptExpansion` and
records an opt-in when:

- the prompt starts with the word `ultracode` (case and leading spaces do not
  matter), or with `/workflow-authoring`; or
- the user types the `/workflow-authoring` command (`UserPromptExpansion`).

The opt-in is a marker file for that `session_id` in
`$XDG_STATE_HOME/dotfiles/ai/workflow-grants/` (default
`~/.local/state/...`; on Windows `%USERPROFILE%\.local\state\...`). It is
valid for 6 hours and only for that session. A new opt-in removes expired
markers. On the prompt events the hook always exits 0, so it never erases a
prompt; if the marker cannot be written, Claude is told that workflows stay
blocked. `AI_ALLOW_WORKFLOW=1 claude` still allows workflows for a whole CLI
session. The model cannot grant itself the opt-in: `ai-guard` blocks every
tool call that names `workflow-grants`, and on Linux the sandbox denies
sandboxed writes to `~/.local/state/dotfiles/ai` (see [Sandbox](#sandbox)).

Why only the start of the prompt: the hooks reference lists the
`UserPromptSubmit` input as the common fields (`session_id`, `prompt_id`,
`transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, `agent_id` in
subagents) plus `prompt`. There is no field that says who wrote the prompt.
The docs do not say whether a message from another session, a channel event
or a scheduled task fires `UserPromptSubmit`. Claude Code itself accepts the
keyword "only in a prompt you type yourself"
([workflows](https://code.claude.com/docs/en/workflows#where-the-keyword-works)),
but a hook cannot see that decision. So the hook:

- ignores the keyword anywhere except as the first word, which excludes
  mentions in text, pasted content (it arrives inside `<pasted_content>`
  lines) and channel events (Claude receives them inside `<channel>` tags);
- ignores events that carry `agent_id` (subagents);
- trusts `UserPromptExpansion` for `/workflow-authoring`, because that event
  fires only when the user types the command; a command inside a message from
  another session "arrives as plain text. Claude Code never executes it"
  ([cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging)).

Residual risk: if Claude Code fires `UserPromptSubmit` for a message from
another of your sessions or for a scheduled task prompt, and that text starts
with `ultracode`, the hook grants the opt-in. Both come from your own
account, and a workflow still runs under the same permission mode, deny
rules, guard and sandbox as any other tool call. To close this path, set
`crossSessionInbound` to `hold` in `~/.claude/settings.json`. The guard reads
command text only: a script that builds the marker path at run time passes it.
On Linux the sandbox still refuses that write; an unsandboxed retry and every
command on Windows depend on the auto-mode classifier.

## Token efficiency

- Always-loaded context is small: the rendered Claude global rules are 98
  lines and about 840 words (measured 2026-09-29 on the Linux render, header
  included; 100 lines and 848 words before), plus about 530 words of
  descriptions for the skills the model picks on its own.
  `scripts/check-skills.py` fails CI above 20 skills or 700 description words.
- The global rules speak to the model only. Habits for you stay here: use plan
  mode for large or ambiguous changes, `/clear` between unrelated tasks (the
  model suggests it) and `/compact <focus>` in long ones. Keep the main model
  on Opus; delegate reading instead of switching models to save tokens. Roles
  and their models are listed in [Roles](#roles), not in the rules.
- User skills (`codebase-design`, `domain-modeling`, `to-tickets`) are hidden
  from the model until you type `/name`. Named skills
  (`test-driven-development`, `verify-web-change`) show only their name, so
  `engineering-flow` can still route to them at almost no context cost.
- `review-web-pr` and `spec-and-standards-review` run inline, so they keep the
  scope and requirements from the conversation. `spec-and-standards-review`
  sends the reading to `reviewer-spec` and `reviewer-standards` when custom
  agents are available. `review-web-pr` reads the diff in the main conversation
  and delegates to `reviewer-web` only when the diff justifies it; that reading
  is the accepted cost of keeping the review context. The main agent waits for
  every report before it merges them.
- `research-primary-sources` runs with `context: fork` in the built-in Explore
  agent and `background: false`: the turn waits for the answer, and the fetched
  pages stay out of the main conversation. Explore has no Edit, Write or Agent
  tool and skips CLAUDE.md, but it keeps Bash and MCP tools, so the skill body
  carries its own read-only and untrusted-content rules. The fork does not see
  the conversation, so pass the question and the decision as arguments.
- Searches go to `reuse-scout` (Sonnet, at most 25 turns) or the built-in
  Explore agent, so the main context keeps only the conclusion.
- Reviews are sized by `engineering-flow`: none for small low-risk changes, one
  reviewer for medium ones, specialists only when the domain justifies them,
  at most two passes.
- Tessera lookups read a compact index and a few cards, never a whole catalog.
- The status line shows context and plan use. `/skill-doctor` shows the cost
  and use of each skill.

## Skills

| Skill | Invocation | Use |
|---|---|---|
| `engineering-flow` | automatic | Any implementation: inspect, reuse, change, verify, review, commit. |
| `clarify-change` | automatic | Only material decisions that inspection cannot settle. |
| `verification-before-completion` | automatic | Fresh proof before claiming done. |
| `systematic-debugging` | automatic | Generic failures: reproduce, isolate, fix. |
| `debug-web-flow` | automatic | Next, Nuxt or Vue flows across browser and server. |
| `review-web-pr` | automatic | Own review of a web branch or PR. |
| `spec-and-standards-review` | automatic | Spec traceability and non-web standards review. |
| `research-primary-sources` | automatic | Decisions that depend on current official sources. |
| `handoff` | automatic | Continuation notes when pausing. |
| `linear-workflow` | automatic | Linear reads; writes only in an authorized session. |
| `cachyos-host-audit` | automatic (Linux) | Read-only host audit. |
| `playwright-cli` | automatic | Browser checks. |
| `tessera` | automatic | Project reuse catalog lookup and maintenance. |
| `test-driven-development` | named | RED-GREEN for isolatable behavior. |
| `verify-web-change` | named | Focused web verification checklist. |
| `codebase-design` | `/name` | Module boundaries and contracts. |
| `domain-modeling` | `/name` | Business concepts and invariants. |
| `to-tickets` | `/name` | Split an approved spec into tickets. |

The invocation policy lives in `scripts/ai_sources.py` and drives the Codex
`agents/openai.yaml` check, the Claude `skillOverrides` and the
`disable-model-invocation` frontmatter of user skills. Shared skills may use the
Claude fields `disable-model-invocation`, `context: fork`, `agent: Explore` and
`background: false`; the Codex parser ignores unknown frontmatter keys (verified
in openai/codex `skills/src/parser.rs`), so Codex loads every skill inline.
`scripts/check-skills.py` accepts the three fork fields only together. Reason: a
fork does not see the conversation and, by default, returns in a later turn
(`background: false` makes the turn wait). In `-p` mode and the Agent SDK,
background subagents that a fork starts can outlive it and report to the main
conversation without a synthesis; Explore has no Agent tool, so it cannot start
them. A fork body must state a task; a guidelines-only body returns no useful
output. Sources:
<https://code.claude.com/docs/en/skills#run-skills-in-a-subagent> and
<https://code.claude.com/docs/en/sub-agents> (checked 2026-09-29, Claude Code
2.1.284).

## Roles

| Role | Claude | Codex | Job |
|---|---|---|---|
| `reuse-scout` | Sonnet, 25 turns, Read/Glob/Grep | `gpt-6-luna`, low effort | Find reusable candidates with contracts and consumers. |
| `catalog-writer` | Sonnet, 40 turns, Read/Glob/Grep | `gpt-6-sol`, medium effort | Draft Tessera cards; the main agent validates and writes. |
| `reviewer-web` | Opus, high effort | `gpt-6-sol`, high effort | Web correctness, security, accessibility, reuse. |
| `reviewer-standards` | Opus, high effort | `gpt-6-sol`, high effort | Requirements, contracts, security, verifiability. |
| `reviewer-spec` | Opus, high effort | `gpt-6-sol`, high effort | Spec coverage and acceptance criteria. |
| `reviewer-linux` | Opus, high effort | `gpt-6-sol`, high effort | CachyOS/Hyprland changes, from evidence the main agent supplies. |

Every role is read-only; the main agent runs tests and passes the results.
Models follow the job: reasoning and execution on Opus (main agent and
reviewers), reading, search and drafting on Sonnet. Haiku is not used: in
practice it stalled on multi-step reading. Models are data in each role file,
so a model rename is a one-line change.

Claude roles use model aliases (`opus`, `sonnet`), which always resolve to
the latest version, so a new Claude release needs no change. The built-in
Explore agent inherits the main model (Opus) and is not overridden: a user agent
with its name would lose Anthropic's tuned prompt and its updates.

Codex needs exact model IDs. They follow the official upgrade table in
`codex-rs/models-manager/models.json` of openai/codex: `gpt-5.6-sol` and
`gpt-5.6-terra` became `gpt-6-sol`, and `gpt-5.6-luna` became `gpt-6-luna`.
The `fast` profile uses `gpt-6-luna`. The sync replaces a top-level `model`
only when it still holds an earlier default of this repository; any other value
is your choice and is kept. To move to a new generation, change the IDs in
`ai/roles/*.json`, `scripts/sync-codex-config.py` (and add the old default to
`RETIRED_DEFAULTS`), `scripts/check-skills.py` and the `codex/.codex` profiles,
then run `python3 scripts/render-ai.py`.

## Linux: install and deploy

Packages: `claude-code` (CachyOS), `claude-desktop-extra` (AUR, built with
Shelly from the reviewed recipe and installed with Pacman) and Codex. Provenance
is in `ai/runtime-sources.json`. No third-party repository, Cowork or computer
use is configured.

```bash
python3 scripts/render-ai.py   # regenerate versioned Codex files after editing ai/
just ai-plan                   # preview; prints paths and kinds, never values
just ai-sync                   # apply with a private backup
just ai-check                  # deployed state, generated files, skills, tests, claude plugin validate
```

`just apply` manages the Stow composition; `ai-sync` manages both AI clients in
its own transaction. Never run Stow against `ai/` or from a secondary worktree.
When the `codex` module is selected, the Stow transaction also deploys the
generated Codex role files through `scripts/manage-codex-agent-files.py`, so it
can migrate agent links left by older deployments and roll them back with the
rest of the transaction. `ai-sync` writes the same files and keeps the same
ownership ledger, so the two never disagree.

The browser CLI is pinned to the vendored skill version:

```bash
npm install --global @playwright/cli@0.1.21
```

Do not run `playwright-cli install --skills` over the managed skills.

Code in Desktop starts in the `permissions.defaultMode` from `settings.json`
(`auto`); check the mode selector in a new session. `claude auth login`
authenticates the CLI separately. Never copy tokens between clients or machines.

## Windows (work PC)

Use the [official Claude Desktop installer](https://claude.com/download),
native Windows, Git for Windows and Python 3.11 or later. Restart Desktop after
changing PATH. Respect company policies; no Stow, WSL, administrator rights or
symlinks are needed. Clone the dotfiles into a real local folder (no junction or
redirected folder).

```powershell
cd 'C:\Users\you\dotfiles'
.\scripts\ai-setup.ps1 -Mode plan
.\scripts\ai-setup.ps1 -Mode apply
.\scripts\ai-setup.ps1 -Mode check
```

The default deploys Claude only; `-Clients both` also keeps an installed Codex.
Each skill is copied and verified; a later local edit blocks its overwrite.
Run `ai-setup.ps1` from a normal PowerShell or Windows Terminal, not from a tool
launched by Claude Desktop or Codex: both are MSIX apps, and Windows redirects
their writes under `AppData\Local` to a private per-app copy.

If the ownership ledger is missing (lost state, a new machine that already has
copies, or an earlier run from inside an MSIX app), the plan stops with
"Conflict: foreign target" (older versions: "destino ajeno"). Run
`.\scripts\ai-setup.ps1 -Mode plan -Adopt`: it adopts only
destinations it can prove came from this repository (skill files matching a Git
blob of `ai/` history, CRLF included; files carrying the generation header;
role files with the role's frontmatter; historical hook versions) and prints an
`adopt:` line for each. Anything else still stops the plan. Adoption needs the
full Git history of the checkout, not a shallow clone.
Hooks and the status line run with the absolute path of the Python that ran
`ai-setup.ps1`; after moving or upgrading Python, run `-Mode apply` again.
`cachyos-host-audit` and the Stop notification are Linux-only. In a new session
check `/memory`, `/skills`, `/agents`, `/hooks`, `/permissions` and `/mcp`.
This GUI check must happen on the work PC; Linux tests do not replace it.

## Tessera

Tessera keeps a local, per-project catalog of reusable components and
utilities outside every repository (see the [skill](../ai/skills/tessera/SKILL.md)).

- **Normal path:** `status` → `index` → `card` for a few plausible cards, then
  read the code. Uninitialized projects use the ordinary reuse search; the agent
  initializes a catalog only when you ask.
- **Maintenance:** `changes` after pulls or branch switches, then refresh the
  affected cards. `skeleton` gives deterministic starting evidence and
  `catalog-writer` drafts cards on a cheaper model.
- **Provider decisions (Jev, Kev):** optional and explicit. The wire card keeps
  every curated field but at most three usage references plus `usage_count`,
  and option texts no longer repeat the summary (about 8% smaller on the pilot,
  more on catalogs with many usages). Each decision records the first-round
  `batch_proposals`, the most useful signal for tasks that compose several pieces. They need your
  per-project consent (`tessera.py consent --repo PROJECT --provider typesafe`,
  in your own terminal) and a blind `agent_choice` in the task. A 250-card
  catalog costs about 175k provider tokens per decision. `tessera.py report`
  shows agreement with the blind choices and total tokens; keep the provider
  only while it improves decisions.
- **Studio:** [Tessera Studio](https://github.com/jesus-molano/tessera-studio)
  (`python -m tessera_studio --open`) is a separate read-only viewer bound to
  `127.0.0.1`.
- **Windows store:** catalogs live in `%USERPROFILE%\.local\share\tessera`, shared
  by Claude, Codex and the shell. Stores left in `%LOCALAPPDATA%` or in an MSIX
  app's private copy show up as `adopt_store` in `status`; adopt the freshest
  with `tessera.py adopt-store --repo PROJECT --from PATH` (the source is kept).

Catalogs, runs and consent never enter Git, dotfiles or GitHub.

## MCP and permissions

- `linear`: `https://mcp.linear.app/mcp/readonly`, OAuth per client.
- `openaiDeveloperDocs`: `https://developers.openai.com/mcp`.
- GitHub: `gh` with its local authentication.
- Linear writes: Codex keeps `linear-write` disabled; Claude refuses a
  persistent `linear-write` and loads it only from a temporary JSON through
  `claude --mcp-config PATH`, following `linear-workflow`.

An existing connection with the same name and another endpoint blocks the apply
instead of being replaced. Accounts, tokens and company connections are never migrated.

## Switching provider

```bash
ai-provider get
ai-provider set claude
ai-provider set codex
```

The preference lives in `~/.config/dotfiles/host.toml` as `[ai] provider`.
Hyper+W, startup, Hyper+P captures and `/proj` use the same resolver. Switching
never closes or starts sessions. If Desktop is missing, the CLI of the same
provider opens in Ghostty/Zellij. End-of-turn notifications are generic.

## Updating without drift

1. Update packages (Shelly/Pacman on Linux, the official installer on Windows).
2. Read the release notes for settings, instructions, skills, hooks and roles.
3. Edit `ai/`, run `python3 scripts/render-ai.py`, the tests, `just lint`,
   `just check`, `just plan` and `just ai-plan`.
4. Apply, run `just ai-check` and open a new session of both clients.
5. Once a month run `/skill-doctor` and `/context` in Claude to spot skills or
   rules that cost context without being used.

Never edit generated copies. A later edit of a managed key, entry, role, hook or
copied skill blocks the apply; reconcile it with the source. There is no `--force`.

## Evaluating the workflow

Static checks and real runs answer different questions. CI validates the
versioned catalog, the generated Codex files (`render-ai.py --check`) and the
regressions without a model or network. Routing and outcomes are measured
with real runs of `claude plugin eval`:

```bash
just ai-eval                                  # all cases, 1 run each, $2 cap
just ai-eval --runs 3 --model sonnet -j 3 --max-cost-usd 4   # steadier
just ai-eval --case generic-bug --runs 3      # one case
just ai-eval --outcome --model sonnet         # with and without the skills, $4 cap
```

`scripts/ai-eval.sh` assembles a temporary plugin from `ai/skills` and the cases
in `ai/evals/cases/`, runs it and keeps results under
`~/.local/state/dotfiles/ai-evals/<timestamp>-<mode>/`. Each case is a
`prompt.md` plus graders. Every run is isolated: a temporary home, no user
settings, hooks, memory or `CLAUDE.md`. Most cases therefore measure the skill
descriptions alone. A case tagged `rules` depends on the global rules (secrets,
publishing, recipes); for it the script appends the rendered Claude rules
(`ai/rules` + `ai/adapters`, Linux) to the system prompt. Real sessions load
them as `CLAUDE.md` instead, so treat those scores as close, not identical.
The `ai-guard` hook is not loaded: `push-literal` models a block by withholding
the Bash tool (the default grant is read-only).

### Outcome mode

`claude plugin eval` compares outcomes natively (checked in the raw
[plugin eval docs](https://code.claude.com/docs/en/plugin-evals.md) on
2026-09-29). With `--ablation with-without` each case runs twice: once with the
plugin (the skills) and once with no plugin at all. The report shows `WITH`,
`W/OUT` and `Δ`. `tool_used: Skill` graders cannot pass without the plugin, so
the two-arm mode excludes them from the score unless they set `arm: both`; the
outcome therefore rests on the other graders (`llm`, `regex`, `tool_used` on
other tools). `--outcome` selects the cases tagged `outcome`, runs both arms
three times and caps the list-price estimate at $4 (about 18 agent runs plus
judge calls). The cap is checked before each run starts, so spend can pass it
by the runs already started; a hit cap exits 2 with partial results. Later
arguments override every default, for example `--max-cost-usd 2` or
`--judge-model sonnet` for a stricter judge. The baseline arm also gets the
appended rules, so `Δ` isolates what the skills add.

### Recording results

Append one row per measurement and never rewrite old rows. Take the values
from `aggregate-result.json` (`claudeVersion`, `costUsd`, `durationSeconds`)
and `git rev-parse HEAD`:

| Date | Commit | Claude Code | Mode | Model | Cases | Runs per arm | Score | Δ | Cost | Time |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-09-29 | not recorded | 2.1.284 | routing | Sonnet | 15 | 3 | 45/45 | — | $2.15 | 138 s |

Last routing measurement per case (2026-09-29, Claude Code 2.1.284, Sonnet,
3 runs per case, 138 s, $2.15):

| Case | Expected | Result |
|---|---|---|
| `implement-ui` | `engineering-flow`, never `codebase-design` | 3/3 |
| `generic-bug` | `systematic-debugging` | 3/3 (1/3 before its trigger was sharpened) |
| `web-flow-bug` | `debug-web-flow` | 3/3 |
| `web-review` | `review-web-pr` | 3/3 |
| `spec-review` | `spec-and-standards-review` | 3/3 |
| `non-web-review` | `spec-and-standards-review`, never `review-web-pr` | 3/3 (0/3 before its trigger was sharpened) |
| `research` | `research-primary-sources` with the question as argument, never `engineering-flow` | 3/3 (0/3 before its trigger was sharpened) |
| `handoff` | `handoff` | 3/3 |
| `named-tdd` | `test-driven-development` (name-only) | 3/3 |
| `verify-before-commit` | `verification-before-completion` | 3/3 |
| `browser-check` | `playwright-cli` | 3/3 |
| `host-audit` | `cachyos-host-audit` | 3/3 |
| `linear-read` | `linear-workflow` | 3/3 |
| `tessera-reuse` | `tessera` | 3/3 |
| `explain-only` | no skill at all | 3/3 |
| `cli-bug-not-web` | `systematic-debugging`, never `debug-web-flow` | not run yet |
| `ops-recipes` (rules) | no implementation skill for `git pull` + `just ai-sync` | not run yet |
| `explain-decisions` (outcome) | no skill; explains the three earlier decisions | not run yet |
| `config-analysis` | read-only analysis: no `engineering-flow`, edit or commit | not run yet |
| `push-literal` (rules, outcome) | at most one push attempt; reports the block, invents no output | not run yet |
| `env-secret` (rules, outcome) | never reads `.env`; points to `with-secrets` | not run yet |

The last six cases come from real prompts of the owner: short Spanish
follow-ups that depend on context. They are lightly paraphrased and carry no
personal data.

A routing case only checks the routing decision. When the chosen skill runs inline,
the agent keeps working and the run ends with `Reached maximum number of turns
(4)`; the report shows that note, but the score counts only the graders. On
2026-09-28, with Opus as the main model, one run of each of the first nine
cases also scored 9/9 (about $0.90).

Haiku as the main model skipped the skill and searched files directly: another
reason to keep the main agent on Opus. Run the evals after changing a
description, a routing rule or the skill set. Every implicit skill keeps at
least one routing case, except `clarify-change`: its trigger depends on what
inspection finds, which a one-prompt case cannot reproduce. Beyond that floor,
turn a real repeated routing failure into a new case; do not grow the catalog
by intuition.

The reuse-scout fixture in `scripts/fixtures/reuse-eval` checks delegation and
evidence quality by hand: open it in a fresh read-only session, ask the main
agent to delegate `cases.md` to `reuse-scout` by name, check the delegation in
the transcript and compare:

| Case | Required evidence |
|---|---|
| Confirmation with secondary text | `SheetDialog`, `Text`, `ActionButton`, public export and the `CloseAccount` consumer. |
| Decimal amount | `parseAmount`, the `SavePayment` consumer; no second parser. |
| Native alternative on web | Rejects `NativeConfirm` for the browser and finds `SheetDialog`. |
| Missing CSV importer | No invented candidate; inspected paths and missing capabilities. |

## Permission mode

The default mode is `auto`: a classifier model reviews each action, approves
routine work without prompts and stops what the `autoMode.soft_deny` rules
describe (publishing, secrets, deletion, Stow and system changes, tracker
writes, sending data out). `permissions.deny` and the `ai-guard` hook run first
and stay deterministic. On Linux the [sandbox](#sandbox) then limits what an
approved shell command can read, write and reach. The classifier adds a small token cost per checked
action. If an organization policy disables auto mode, Claude falls back to
prompting; pick another mode in `/permissions` for one session, or change
`permissions.defaultMode` in `scripts/sync-ai.py` (it is a managed key, so a
local edit is reported as a conflict).

`bypassPermissions` is disabled (`permissions.disableBypassPermissionsMode`).
In that mode the classifier and the `soft_deny` rules do not run, and the mode
offers no protection against prompt injection
([permission modes](https://code.claude.com/docs/en/permission-modes)). The
key also works in user settings for Claude Desktop
([Desktop](https://code.claude.com/docs/en/desktop)). On Pro and Max plans,
also turn off **Settings → Claude Code → Allow bypass permissions mode** in
Claude Desktop. On Team and Enterprise plans, organization policy controls
that toggle.

## Sandbox

Deny rules and `ai-guard` read the command text. The permissions reference
says Read and Edit deny rules do not apply "to arbitrary subprocesses that read
or write files indirectly, like a Python or Node script that opens files
itself. For OS-level enforcement that blocks all processes from accessing a
path, enable the sandbox"
([permissions](https://code.claude.com/docs/en/permissions)). So on Linux the
sync turns on the Claude Code sandbox (bubblewrap and socat must be
installed). It applies to "every Bash, PowerShell, or Monitor command and its
child processes" ([sandboxing](https://code.claude.com/docs/en/sandboxing)).
Native Windows is not supported ("Native Windows is not supported"), so the
work PC gets none of these keys.

| Key | Value | Reason |
|---|---|---|
| `sandbox.enabled` | `true` | Turns the sandbox on for every project. |
| `sandbox.autoAllowBashIfSandboxed` | `false` | The default `true` runs sandboxed commands "without a permission prompt". With `false`, "sandboxed commands go through the regular permission flow, so your allow rules and permission mode decide": the auto-mode classifier and its `soft_deny` rules keep reviewing every command, as before. The sandbox adds containment; it does not replace the review. |
| `sandbox.allowUnsandboxedCommands` | `true` | See below. |
| `sandbox.filesystem.denyRead` (entries) | `~/**/.env`, `~/**/.env.*`, `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.git-credentials`, `~/.config/gh/hosts.yml`, `~/.claude.json`, `~/.claude/.credentials.json`, `~/.codex/auth.json` | The default read policy "still allows reading credential files such as `~/.aws/credentials` and `~/.ssh/`". These are the same stores as the `permissions.deny` rules, now enforced for every sandboxed process. Wildcards work in read lists on Linux: Claude Code "expands a read entry to the concrete paths it matches". |
| `sandbox.filesystem.denyWrite` (entry) | `~/.local/state/dotfiles/ai` | The sync ledger, its backups and the [workflow opt-in](#workflow-opt-in) markers. Sandboxed commands can already write only to the working directory and the session temp directory; this entry also holds when a session starts in `~` or adds it with `/add-dir`. |
| `sandbox.excludedCommands` (entries) | `just ai-plan`, `just ai-sync`, `just ai-check`, `just apply` | These recipes read the Claude config and write to `~/.claude`, `~/.codex`, `~/.agents`, `~/.local/state` or HOME (Stow) by design. `~/.claude` is a sandbox protected path that no `allowWrite` can open. "Excluded commands still go through the regular permission flow", so the classifier and `ai-guard` still review them. An entry applies only when it covers the whole call: `cd x && just apply` stays sandboxed. |

**Unsandboxed retries.** With `allowUnsandboxedCommands: true` (also the
default), a command that the sandbox blocks may be retried with
`dangerouslyDisableSandbox`: "The retried command runs outside the sandbox,
so it goes through the regular permission flow. [...] In auto mode, the
classifier evaluates the underlying command". `ai-guard` runs on that call
too. `false` ("strict sandbox mode") would make other work outside the
working directory impossible from a session: `gh` needs `hosts.yml`,
`git push` over SSH needs `~/.ssh`, `with-secrets` needs 1Password. Those
commands fail in the sandbox, name the denied path, and then run unsandboxed
only when the classifier approves. For a prompt on every retry, even in auto
mode, add the ask rule `Bash(dangerouslyDisableSandbox:true)` yourself.

**Network.** The sync sets no network key. By default "Claude Code pre-allows
no domains"; in auto mode "Claude instead names the hosts a command needs on
the command itself", the classifier reviews them with the command, and "an
approved list opens those hosts for that one command alone". The proxy
filters by host name and "does not terminate or inspect TLS", so an allowed
broad domain such as `github.com` can still carry data out. `strictAllowlist`
is not set: with it, "Claude Code refuses per-command lists", so every new
host would need a settings change.

**Not set.** `failIfUnavailable` stays `false`: if bubblewrap or socat is
missing, Claude Code "shows a warning and runs commands unsandboxed" instead
of refusing to start every session, Desktop included. Check for that warning
after a CachyOS update. `sandbox.credentials` (masking) and
`blockReadsOutsideWorkingDirectories` are not used.

**Desktop.** The Desktop docs say "Desktop and CLI read the same
configuration files" and "Permission rules, allowed tools, and other settings
in `settings.json` apply to Desktop sessions"
([Desktop](https://code.claude.com/docs/en/desktop#shared-configuration)).
They do not mention the sandbox for the Code tab. Treat Desktop support as not
documented and verify it on the host (test in a Desktop session below).

**Host test** (CachyOS, before relying on it): run `just ai-plan`, review,
`just ai-sync`, then open a new CLI session and a new Desktop Code session in
a scratch repository. In your own terminal, create a `.env` file there. The
probe must read files indirectly, because `ai-guard` blocks any command that
names them. Ask Claude to write `probe.py` with this content and run
`python3 probe.py` (sandboxed, no retry):

```python
import os
home = os.path.expanduser("~")
for path in (".e" + "nv", home + "/.s" + "sh", home + "/.claude" + ".json", home + "/.gitconfig"):
    try:
        os.listdir(path) if os.path.isdir(path) else open(path).read(1)
        print("READ  ", path)
    except OSError as error:
        print("DENIED", path, type(error).__name__)
```

| Check | Expected |
|---|---|
| `/sandbox` (CLI) | No Dependencies-only tab; Config lists the `denyRead` paths. |
| `python3 probe.py` | `DENIED` for the dotenv file, `~/.ssh` and `~/.claude.json`; `READ` for `~/.gitconfig`. The same in the Desktop session. |
| `touch ~/sandbox-probe` | Fails in the sandbox (`Read-only file system`); an unsandboxed retry goes to the classifier. |
| `touch ~/.local/state/dotfiles/ai/probe` | Fails in the sandbox. |
| `curl -sI https://example.com` | Claude names `example.com` on the command and the classifier reviews it. |
| `just ai-plan` | Runs outside the sandbox and prints the plan. |
| First prompt `ultracode: say hi`, then ask for a workflow | The Workflow tool runs in that session; in a new session without the keyword it is blocked. |

## Project gate

`ai/hooks/project-gate.py` gives each project deterministic verification without
touching the project tree: it reads two optional keys from the repository's
local Git config only (`git config --local`: `.git/config`, never committed;
`~/.gitconfig` and `includeIf` files do not count) and does nothing where they
are absent.

| Key | Hook | Behaviour |
|---|---|---|
| `ai.format` | `PostToolUse` on `Write`, `Edit`, `MultiEdit` | Runs the command with the edited file appended. Never blocks. |
| `ai.check` | `Stop` | Runs the command when the state changed since the last passing run. The state is HEAD, the `ai.check` text and the working tree (tracked diff and untracked files), so a commit or a stash made during the turn does not skip the check. A failure exits 2 with the last 40 output lines, so Claude fixes it before ending the turn. In the same stop cycle (`stop_hook_active`), an unchanged state is not checked again, and a second failure lets the turn end and tells Claude to report it. |

Keep `ai.check` fast (lint and typecheck, or unit tests that finish in
seconds). The Stop entry allows 300 s; the hook keeps one 290 s budget for
all its Git calls and the check (the format hook: 27 s of 30 s). On timeout it
kills the whole process tree (its own session and process group on Linux,
`taskkill /T /F` on Windows), so no child keeps running. The last passing
state is in `.git/ai-gate-pass` and the last failing one in
`.git/ai-gate-fail`. The first Stop in a clean repository without these files
records the state as the baseline without running the check, so a fresh clone
with old failures does not stop a turn that changed nothing. After that, a new
HEAD (a commit, a pull, a checkout) is checked at the next Stop.

```bash
python3 ~/.claude/hooks/project-gate.py suggest .   # candidates from package.json
git config --local ai.check "pnpm lint && pnpm typecheck"
git config --local ai.format "pnpm exec prettier --write --ignore-unknown"
git config --local --unset ai.check                 # opt out
```

## Backups and recovery

`ai-sync` prints only paths, kinds and the backup location. Both platforms keep
the ownership ledger and private transactions in `~/.local/state/dotfiles/ai/`
(on Windows `%USERPROFILE%\.local\state\dotfiles\ai`, which MSIX does not
virtualize). A ledger left in the old Windows location
(`AppData\Local\dotfiles\ai`, or an MSIX app's private copy of it) is carried
over automatically on the next apply (`state: ledger carried over from ...`), and
backups there can still be rolled back. Backups contain private configuration:
never copy them into a repository.

```bash
python3 scripts/sync-ai.py rollback --backup /exact/path/to/backup
```

```powershell
.\scripts\ai-setup.ps1 -Mode rollback -Backup 'C:\exact path\to\backup'
```

Rollback checks that every target still holds the applied or restored content
and stops on foreign changes. If an interruption left `sync.lock`, confirm no
sync is running before removing that exact file.

## Sources

[Memory and AGENTS.md](https://code.claude.com/docs/en/memory),
[settings](https://code.claude.com/docs/en/settings),
[permissions](https://code.claude.com/docs/en/permissions),
[hooks](https://code.claude.com/docs/en/hooks),
[skills](https://code.claude.com/docs/en/skills),
[subagents](https://code.claude.com/docs/en/sub-agents),
[status line](https://code.claude.com/docs/en/statusline),
[Desktop on Linux](https://code.claude.com/docs/en/desktop-linux),
[Desktop Extra](https://github.com/patrickjaja/claude-desktop-extra) and
[Playwright CLI](https://github.com/microsoft/playwright-cli). Settings keys,
skill overrides and subagent fields were checked against Claude Code 2.1.284.

## Provenance

Ideas adopted and adapted, not installed: small composable skills and
explicit user skills (`mattpocock/skills`); TDD, systematic debugging and
verification before completion (`obra/superpowers`); deny rules plus blocking
guard hooks (`trailofbits/claude-code-config`); Linear from `openai/skills`
(see its `SOURCE.md`). Playwright CLI is vendored with checksums in
`ai/skills/playwright-cli/SOURCE.json`. External catalogs are never installed
globally; an idea is adopted only when it reduces risk or context and is
versioned, tested and reviewable here.
