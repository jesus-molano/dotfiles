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
| `permissions.defaultMode` | `bypassPermissions` | No technical prompts (owner's choice). |
| `permissions.deny` (entries) | `.env*` read/edit, `~/.ssh`, `~/.gnupg`, `~/.aws`, Git and gh credentials, `~/.claude.json` | Deny rules still apply in bypass mode. |
| `hooks.PreToolUse` (entry) | `ai-guard.py` on `Bash`, `PowerShell`, `Workflow` | Blocks the hard limits deterministically. |
| `hooks.Stop` (entry, Linux) | `claude-notify` | Generic desktop notification at end of turn. |
| `statusLine` | `statusline.py` | Model, project:branch, context %, 5h and 7d plan use. |
| `attribution.*` | empty / `false` | No co-author trailers or session links. |
| `pluginConfigs["agents-md@builtin"]` | `claude-md-and-agents-md` | Loads `AGENTS.md` next to `CLAUDE.md`. |
| `skillOverrides` | `user-invocable-only` for explicit skills | Hidden from the model, still `/name`. |

A managed entry that you remove by hand is reported as a conflict instead of
being silently re-added; review it and reconcile it with the source.

## Guardrails

`ai/hooks/ai-guard.py` runs before every shell command and every `Workflow`
call. It exits 2 (block) with a short reason, and never prints the command,
file contents or environment. It blocks only what is never part of a normal task:

| Blocked | Rule it enforces |
|---|---|
| `git push` with force, `--force-with-lease`, delete, mirror, `--tags`, `--all`, `+ref`, `:ref` or several refspecs | Publish one verified ref, never rewrite or delete remote history. |
| `stow` with a glob of packages | Never run Stow over every directory. |
| `rm -r` of `/`, `~`, `$HOME` or the dotfiles checkout | No catastrophic deletion. |
| Any command naming a `.env` file (templates `*.example`, `*.template`, `*.sample` allowed); `op read`, `op inject`, `op item`, `op document` | Secrets only through `with-secrets`. |
| `tessera.py consent` | Only the user grants provider consent. |
| `Workflow` tool | Multi-agent workflows only on request. Start a session with `AI_ALLOW_WORKFLOW=1 claude` to allow them. |

A normal `git push origin <branch>` is allowed: the rule to show the exact OID
and ask for authorization before publishing stays in the global rules. The
guard is a safety net, not a sandbox: a determined script can still reach a
secret, so keep secrets out of the environment and use `with-secrets`.

## Token efficiency

- Always-loaded context is small: about 680 words of global rules and about 470
  words of descriptions for the skills the model can pick (explicit skills are
  hidden). `scripts/check-skills.py` fails CI above 20 skills or 700
  description words.
- Explicit skills (`codebase-design`, `domain-modeling`, `to-tickets`,
  `test-driven-development`, `verify-web-change`) are hidden from the model and
  cost nothing until you type `/name`.
- Searches go to `reuse-scout` (Haiku, at most 25 turns) or the built-in Explore
  agent, so the main context keeps only the conclusion.
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
| `test-driven-development` | `/name` | RED-GREEN for isolatable behavior. |
| `verify-web-change` | `/name` | Focused web verification checklist. |
| `codebase-design` | `/name` | Module boundaries and contracts. |
| `domain-modeling` | `/name` | Business concepts and invariants. |
| `to-tickets` | `/name` | Split an approved spec into tickets. |

The invocation policy lives in `scripts/ai_sources.py` and drives both the
Codex `agents/openai.yaml` check and the Claude `skillOverrides`.

## Roles

| Role | Claude | Codex | Job |
|---|---|---|---|
| `reuse-scout` | Haiku, 25 turns, Read/Glob/Grep | light model, low effort | Find reusable candidates with contracts and consumers. |
| `catalog-writer` | Sonnet, 40 turns, Read/Glob/Grep | medium model | Draft Tessera cards; the main agent validates and writes. |
| `reviewer-web` | Opus, high effort | main model, high effort | Web correctness, security, accessibility, reuse. |
| `reviewer-standards` | Opus, high effort | main model, high effort | Requirements, contracts, security, verifiability. |
| `reviewer-spec` | Opus, high effort | main model, high effort | Spec coverage and acceptance criteria. |
| `reviewer-linux` | Opus, high effort | main model, high effort | CachyOS/Hyprland changes, from evidence the main agent supplies. |

Every role is read-only; the main agent runs tests and passes the results.
Models are data in each role file, so a model rename is a one-line change.

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

The browser CLI is pinned to the vendored skill version:

```bash
npm install --global @playwright/cli@0.1.21
```

Do not run `playwright-cli install --skills` over the managed skills.

In Desktop open **Settings → Claude Code**, enable **Allow bypass permissions
mode** and pick **Bypass permissions** in a new session. `claude auth login`
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
Hooks run with `python`; the status line and `ai-guard` need Python on PATH.
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
- **Provider decisions (Jev, Kev):** optional and explicit. They need your
  per-project consent (`tessera.py consent --repo PROJECT --provider typesafe`,
  in your own terminal) and a blind `agent_choice` in the task. A 250-card
  catalog costs about 175k provider tokens per decision. `tessera.py report`
  shows agreement with the blind choices and total tokens; keep the provider
  only while it improves decisions.
- **Studio:** [Tessera Studio](https://github.com/jesus-molano/tessera-studio)
  (`python -m tessera_studio --open`) is a separate read-only viewer bound to
  `127.0.0.1`. It also finds the store of MSIX-virtualized apps on Windows.

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

Static checks and a real run answer different questions. CI validates the
versioned catalog and regressions without a model or network. After changing
routing, the scout or role deployment, run the reuse evaluation once:

1. Open `scripts/fixtures/reuse-eval` in a fresh session (Claude:
   `claude --permission-mode plan`; Codex: an ephemeral read-only session).
2. Ask the main agent to delegate `cases.md` to `reuse-scout` by name and wait
   for the result without repeating the search. Do not show it the expected answers.
3. Check the delegation event in the transcript, not a claim in the reply, and
   compare the result:

| Case | Required evidence |
|---|---|
| Confirmation with secondary text | `SheetDialog`, `Text`, `ActionButton`, public export and the `CloseAccount` consumer. |
| Decimal amount | `parseAmount`, the `SavePayment` consumer; no second parser. |
| Native alternative on web | Rejects `NativeConfirm` for the browser and finds `SheetDialog`. |
| Missing CSV importer | No invented candidate; inspected paths and missing capabilities. |

Turn a real repeated workflow failure into a new minimal case here; do not
grow the catalog by intuition.

## Backups and recovery

`ai-sync` prints only paths, kinds and the backup location. Linux keeps private
transactions in `~/.local/state/dotfiles/ai/backups/`; Windows in
`%USERPROFILE%\AppData\Local\dotfiles\ai\backups\`. Backups contain private
configuration: never copy them into a repository.

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
