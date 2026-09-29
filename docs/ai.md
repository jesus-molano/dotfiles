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
| `hooks.PostToolUse` (entry) | `project-gate.py format` on `Write`, `Edit`, `MultiEdit` | Formats the edited file in opted-in projects. See [Project gate](#project-gate). |
| `hooks.Stop` (entry) | `project-gate.py check` | Runs the project's fast checks before the turn ends, in opted-in projects. |
| `hooks.Stop` (entry, Linux) | `claude-notify` | Generic desktop notification at end of turn. |
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
| `Workflow` tool | Multi-agent workflows only on request. Start a session with `AI_ALLOW_WORKFLOW=1 claude` to allow them. |

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
code running as your user can still reach anything you can. It does not expand
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

## Token efficiency

- Always-loaded context is small: about 740 words of global rules and about
  510 words of descriptions for the skills the model picks on its own. `scripts/check-skills.py` fails CI above 20 skills or 700
  description words.
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
- The status line shows context and plan use. Use `/clear` between unrelated
  tasks, `/compact <focus>` in long ones, and `/skill-doctor` to see the cost
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
regressions without a model or network. Routing is
measured with real runs of `claude plugin eval`:

```bash
just ai-eval                                  # all cases, 1 run each, $2 cap
just ai-eval --runs 3 --model sonnet -j 3 --max-cost-usd 4   # steadier
just ai-eval --case generic-bug --runs 3      # one case
```

`scripts/ai-eval.sh` assembles a temporary plugin from `ai/skills` and the cases
in `ai/evals/cases/`, runs it and keeps results under
`~/.local/state/dotfiles/ai-evals/`. Each case is a `prompt.md` plus
`tool_used: Skill` graders. The evals load only the skills, not your
`CLAUDE.md`, so they measure the descriptions alone; real sessions also get the
"skills first" rule. Last measurement (2026-09-29, Claude Code 2.1.284, Sonnet,
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

A case only checks the routing decision. When the chosen skill runs inline,
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
and stay deterministic. The classifier adds a small token cost per checked
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

## Project gate

`ai/hooks/project-gate.py` gives each project deterministic verification without
touching the project tree: it reads two optional keys from the repository's
local Git config (`.git/config`, never committed) and does nothing where they
are absent.

| Key | Hook | Behaviour |
|---|---|---|
| `ai.format` | `PostToolUse` on `Write`, `Edit`, `MultiEdit` | Runs the command with the edited file appended. Never blocks. |
| `ai.check` | `Stop` | Runs the command when the working tree changed since the last passing run. A failure exits 2 with the last 40 output lines, so Claude fixes it before ending the turn. A second failure in the same stop cycle lets the turn end and tells Claude to report it. |

Keep `ai.check` fast (lint and typecheck, or unit tests that finish in
seconds); the hook allows 300 s. The last passing state is cached in
`.git/ai-gate-pass`, so an unchanged tree is not checked twice.

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
