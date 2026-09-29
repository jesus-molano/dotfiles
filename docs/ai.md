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
| `permissions.deny` (entries) | `.env*` read/edit, `~/.ssh`, `~/.gnupg`, `~/.aws`, Git and gh credentials, `~/.claude.json`, `Edit` of Tessera `provider-consent.json` (also inside MSIX app stores) | Deny rules apply before the classifier; `Edit` rules cover every file write. |
| `hooks.PreToolUse` (entry) | `ai-guard.py` on `Bash`, `PowerShell`, `Workflow`, `Write`, `Edit`, `MultiEdit` | Blocks the hard limits deterministically. |
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

`ai/hooks/ai-guard.py` runs before every shell command, every `Workflow` call
and every file write or edit, in Claude Code and in Codex (`~/.codex/hooks.json`,
same schema and stdin contract). Codex runs a new user hook only after you
trust it once in its `/hooks` view. It exits 2 (block) with a short reason, and never prints the command,
file contents or environment. It blocks only what is never part of a normal task:

| Blocked | Rule it enforces |
|---|---|
| `git push` with force, `--force-with-lease`, delete, mirror, `--tags`, `--all`, `+ref`, `:ref` or several refspecs | Publish one verified ref, never rewrite or delete remote history. |
| `stow` with a glob of packages | Never run Stow over every directory. |
| `rm -r` of `/`, `~`, `$HOME` or the dotfiles checkout | No catastrophic deletion. |
| Commands that read a `.env` file (templates `*.example`, `*.template`, `*.sample`, `echo`, `git check-ignore` and copying a template to `.env` are allowed); `op read`, `op inject`, `op item`, `op document` | Secrets only through `with-secrets`. |
| `tessera.py consent` and any write to `provider-consent.json` (redirections, copies, deletes, `sed -i`, inline scripts, PowerShell write cmdlets); reading or searching it is allowed | Only the user grants provider consent. |
| `Workflow` tool | Multi-agent workflows only on request. Start a session with `AI_ALLOW_WORKFLOW=1 claude` to allow them. |

The guard looks through wrappers (`sudo`, `env`, `timeout`, `nohup`, `xargs`),
nested shells (`bash -c`, `eval`), command substitutions and chained commands,
and ignores redirections and heredoc bodies, so `git push -u origin feat 2>&1`
works. A normal `git push origin <branch>` is allowed: showing the exact OID and
asking for authorization before publishing stays in the global rules.

Known limits: the guard is a safety net against mistakes, not a sandbox, and
code running as your user can still reach anything you can. PowerShell has its
own parser (quoting, `${...}` and `%USERPROFILE%` paths, cmdlet aliases such as
`ri`, `gc`, `rd /s`, `-Recurse:$true`, and nested `cmd /c`, `pwsh -Command`
and `Invoke-Expression`). On Windows a command reported as Bash is checked with
both parsers. The `Read(**/.env.*)` deny rule also hides
`.env.example` templates from the Read tool; read them through the shell.

## Token efficiency

- Always-loaded context is small: about 740 words of global rules and about
  470 words of descriptions for the skills the model picks on its own. `scripts/check-skills.py` fails CI above 20 skills or 700
  description words.
- User skills (`codebase-design`, `domain-modeling`, `to-tickets`) are hidden
  from the model until you type `/name`. Named skills
  (`test-driven-development`, `verify-web-change`) show only their name, so
  `engineering-flow` can still route to them at almost no context cost.
- Review and research skills run with `context: fork`, so their reading stays
  out of the main conversation.
- Searches go to `reuse-scout` (Sonnet, at most 25 turns) or `Explore` (Sonnet,
  at most 30 turns), so the main context keeps only the conclusion.
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
Claude fields `disable-model-invocation` and `context: fork`; the Codex parser
ignores unknown frontmatter keys (verified in openai/codex `skills/src/parser.rs`).

## Roles

| Role | Claude | Codex | Job |
|---|---|---|---|
| `Explore` | Sonnet, 30 turns, Read/Glob/Grep | (Claude only) | Replaces the built-in Haiku Explore agent: general read-only search with cited evidence. |
| `reuse-scout` | Sonnet, 25 turns, Read/Glob/Grep | light model, low effort | Find reusable candidates with contracts and consumers. |
| `catalog-writer` | Sonnet, 40 turns, Read/Glob/Grep | medium model | Draft Tessera cards; the main agent validates and writes. |
| `reviewer-web` | Opus, high effort | main model, high effort | Web correctness, security, accessibility, reuse. |
| `reviewer-standards` | Opus, high effort | main model, high effort | Requirements, contracts, security, verifiability. |
| `reviewer-spec` | Opus, high effort | main model, high effort | Spec coverage and acceptance criteria. |
| `reviewer-linux` | Opus, high effort | main model, high effort | CachyOS/Hyprland changes, from evidence the main agent supplies. |

Every role is read-only; the main agent runs tests and passes the results.
Models follow the job: reasoning and execution on Opus (main agent and
reviewers), reading, search and drafting on Sonnet. Haiku is not used: in
practice it stalled on multi-step reading. Models are data in each role file,
so a model rename is a one-line change.

`Explore` is a user agent with the name of the built-in one, so Claude Code
uses it instead of the Haiku default. A role without a `codex` block, like this
one, is rendered only for Claude.

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
versioned catalog and regressions without a model or network. Routing is
measured with real runs of `claude plugin eval`:

```bash
just ai-eval                                  # all cases, 1 run each, $2 cap
just ai-eval --runs 3 --model sonnet          # a steadier measurement
just ai-eval --case generic-bug --runs 3      # one case
```

`scripts/ai-eval.sh` assembles a temporary plugin from `ai/skills` and the cases
in `ai/evals/cases/`, runs it and keeps results under
`~/.local/state/dotfiles/ai-evals/`. Each case is a `prompt.md` plus
`tool_used: Skill` graders. The evals load only the skills, not your
`CLAUDE.md`, so they measure the descriptions alone; real sessions also get the
"skills first" rule. Last measurement (2026-09-28, Sonnet, 3 runs per case):

| Case | Expected | Result |
|---|---|---|
| `implement-ui` | `engineering-flow`, never `codebase-design` | 3/3 |
| `generic-bug` | `systematic-debugging` | 3/3 (1/3 before its trigger was sharpened) |
| `web-flow-bug` | `debug-web-flow` | 3/3 |
| `web-review` | `review-web-pr` | 3/3 |
| `spec-review` | `spec-and-standards-review` | 3/3 |
| `research` | `research-primary-sources`, never `engineering-flow` | 3/3 (0/3 before its trigger was sharpened) |
| `handoff` | `handoff` | 3/3 |
| `named-tdd` | `test-driven-development` (name-only) | 3/3 |
| `explain-only` | no skill at all | 3/3 |

A full run of all cases at 3 runs costs about $1.50 with Sonnet. With Opus,
the main model, one run per case also scored 9/9 (about $0.90).

Haiku as the main model skipped the skill and searched files directly: another
reason to keep the main agent on Opus. Run the evals after changing a
description, a routing rule or the skill set. Turn a real repeated routing
failure into a new case; do not grow the catalog by intuition.

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
