# Tessera contract v1

## Ownership and separation

Tessera is personal tooling. Each project has its own catalog and history,
stored outside Git repositories by default:

- Linux: `${XDG_DATA_HOME:-~/.local/share}/tessera/projects/<id>/`.
- Windows: `%LOCALAPPDATA%\tessera\projects\<id>\` (Claude Desktop installed
  as an MSIX app may see a virtualized copy of that folder).

`tessera.py locate --repo PROJECT` resolves those paths without creating files.
They contain `catalog.json`, `inventory.json`, `history/`, `tasks/`, `runs/`,
`decisions/`, optional `curation/` and `provider-consent.json`. The ID is a hash
of the real local path of `git-common-dir`: linked worktrees share knowledge;
independent clones have separate stores. It uses no remotes, credentials or
identification file inside the project. Moving or recloning the checkout
changes the ID: recover or review the catalog explicitly, never copy it
automatically between machines or companies.

Work projects never get a `.tessera` folder, a `.gitignore` change or
versioned cards or decisions, and their data is never copied to personal
dotfiles or GitHub. Dotfiles ship scripts and skills; the data stays on the
work PC. Catalogs are not synchronized between computers. A transfer needs an
explicit request and an authorized destination. Sharing a catalog in a
repository is an explicit exception, not the default.

`prepare` rejects a catalog, task or output inside any Git checkout; `evaluate`
checks the run location again before writing or calling the provider, even
through a link. `--allow-repo-storage` is required on every affected call and
allows only an expressly authorized sharing flow. Detection uses the `.git`
checkout markers; it is not a sandbox or a data classification system. Never
use the exception for work projects.

`ai/tessera/pilots/expenses-log-app` is the previously published personal
pilot, not a pattern for storing company information or a deployment in the app.

| Layer | Content | Owner |
|---|---|---|
| Curated catalog | Responsibility, contract, constraints, sources and usages | Project and its agents |
| Derived evidence | Inventory, source content, hashes, revision | `prepare`, regenerable |
| Neutral context | Task, complete cards, provenance and options; no full files | Tessera |
| External exchange | Provider-specific request and response, authentication | Provider adapter |
| Decision | Action, identity, provenance, attributed explanation, blind agent choice and outcome | Project |

Tessera stores no conversational memory, work plans or inspiration references.
It uses no Atlas, vector database, Figma or server.

The [lifecycle](lifecycle.md) defines `status`, `init`, `scan`, `review`,
`skeleton` and `finalize`: coverage of the Git tree without tests, resumable
review and freshness. `current` in `changes` describes the scoped cards; only
`ready` in `status` proves a reviewed inventory and a finalized catalog.

## Agent lookup

`index` returns `status`, `next_action` and one compact entry per card (`id`,
`kind`, `name`, `tags`, `summary`, `source`), about 170 bytes per card instead
of the full card. `card --id ID` (repeatable) returns complete cards without
legacy `tests` fields. Both are read-only and offline. The agent may shortlist
from the index: the "no preselection" rule applies only to provider decisions.

## Catalog and growth

UTF-8 JSON with `schema: 1`, `project`, `scope` and `entries`. `scope` lists
project-relative file or directory paths. Directories inventory their files
except tests and test artifacts, excluded by path before content is read as
[lifecycle](lifecycle.md) describes. There is no language list or relevance
filter. Use concrete source scopes; never include HOME, dependencies, user data
or secrets.

Each card contains:

- `id`: stable, lowercase with hyphens; independent of provider and checkout.
- `name`, `tags`: optional; export names and concepts that help discovery.
- `kind`, `summary`, `contract`: nature, responsibility and API or behavior.
  State inputs, outputs, effects and dependencies relevant to the contract.
- `constraints`: limits and missing guarantees, as an explicit list.
- `source`: the file that implements the contract. A card may describe several
  exports of that file.
- `usages`: objects with `path`, `start`, `end` (inclusive lines of a real
  use). Without consumers, `[]` needs a textual `usage_gap` that explains the
  search or the framework's implicit use. Never invent a consumer.
- `tests`: old optional field; ignored without opening or resolving its paths
  and never sent to the provider. Omit it in new cards.

Optional `supporting_files` lists token, style or manifest paths for local
inspection. `derived.json` keeps the full files and hashes. The provider gets
cards, references and curation state, not files. Paths grant no access: no
remote engine can open them. If a fact needed to decide is missing, the agent
inspects the source and enriches the contract or constraints before preparing
another run. Cards are never trimmed and source is never uploaded automatically.
`coverage` and `reviewed_revision` document scope and human or agent review.
A project without catalogable pieces may have `scope: []` and `entries: []`;
reviewing all its files and exclusions is still required to finalize. `kind` is
an extensible semantic class assigned by reading code and consumers, not by a
filename detector. All paths are project-relative. The helper rejects escapes,
links, `.env*`, unknown fields, untracked evidence, duplicate IDs and mismatches
between scope and cards. Local evidence records whole files, deduplicated by
path; the compact request does not contain those texts.
`evidence.curation.status` is `current` when sources match the curated
revision, `stale` when they changed or the revision cannot be resolved, and
`unverified` when it is missing. A commit outside the scope does not invalidate
cards: the Git trees of the evidence paths are compared. `evaluate` rejects
`stale` before sending. Review the meaning as well and update
`reviewed_revision` after curating changes. Keep cards short: an exact contract
and constraints, a one-sentence summary. Card size drives provider cost.

To add a component or utility: inspect its contract and consumer, add the card,
extend the scope if needed, record real usages or gaps, run `prepare` and review
the diff. A new candidate inside a declared scope is a coverage error until it
is curated; ranking never hides it. Prepare evidence from a clean checkout;
after implementing and verifying, create the coherent local commit before
regenerating the snapshot.

### Colleagues' changes and updates

Before each decision, `tessera.py changes --repo PROJECT` compares the
checkout with `reviewed_revision`. It reports new or deleted sources, changed
paths, vanished references, affected cards and uncommitted changes. Renames
appear as a deletion plus an addition that the agent reconciles, keeping the
identity when appropriate. It also returns changes outside the catalog, without
judging their relevance by name, so possible extensions can be inspected.

The agent reads the changes, updates the meaning of the cards and keeps a prior
copy under `history/`; only then does it update `reviewed_revision` and
`reviewed_on`. Adding a component inside the scope requires curating its card.
A missing or unknown revision requires reviewing the whole catalog. Changes
outside a card's sources do not invalidate it automatically.

This happens while working and consulting the catalog, including changes that
arrive with a pull or branch switch. There is no watcher or automatic GitHub
query, and colleagues do not need Tessera installed. `prepare` still requires
versioned sources and a clean checkout; `evaluate` captures the evidence again
before the network and rejects a changed snapshot. An old run without a local
checkout reference must be prepared again. Local manifest paths are never sent
to the provider.

## Neutral decision contract

`context.json` contains `schema`, `task`, `catalog`, `evidence`, `options` and
`instructions`. The task has `id`, `requirement` and a non-empty `acceptance`
list. With `--require-ready` the task file must also carry the agent's blind
`agent_choice` (`action`, `primary` card id or null, `reason`); `prepare`
validates it, stores it in the local manifest and removes it from the context,
so the provider never sees it. Every card is evaluated in each decision; cards
may be spread across requests. The full context stays local and the sent
batches are traced. `evidence` only communicates revision, curation state and
`source_text_included: false`. Full texts stay in `derived.json`, separate from
the neutral context; its hash is checked and the context rebuilt before sending.

Common, model-independent options:

| Action | Meaning |
|---|---|
| `reuse:<id>` | Consume the existing contract without changing it |
| `modify:<id>` | Change implementation or contract and verify its consumers |
| `wrap:<id>` | Compose a task-specific wrapper that keeps the base |
| `create` | New primary implementation; supporting primitives may be reused |
| `insufficient_evidence` | Not enough context to choose on solid ground |

A decision covers one primary responsibility per task. A task with several
responsibilities needs those decisions made explicit; the verdict does not
validate complete plans or multi-target selection.

The normalized output keeps `action`, `primary`, `decided_by` (`provider` or
`coordinator`), provenance, context and request hashes and the revision, plus
`agent_choice` and `agreement` when present. Distribution and confidence, when
the provider offers them, are evidence, never an arbitrary action threshold.
`agent_explanation: null` and `review_status: pending` keep the pending review
visible. Later explanations and references belong to the agent that writes
them. A decision runs no code, publishes nothing and grants no permission.

The core records destinations and hashes without knowing secrets or question
types. Providers are registered explicitly in `PROVIDERS` in
`scripts/tessera.py`. Each adapter implements `build_request`,
`check_credentials`, `invoke`, `parse_response`, `validate_response` and
`endpoint()`. It receives the same context and returns the normalized option,
model, usage and, when available, probabilities and confidence. To add another
engine, implement a real adapter, register it and test it with the same catalog
and cases. Do not change cards or reinterpret old decisions. There are no fake
Claude or Codex adapters and no automatic fallback. Tessera never preselects by
tags, relevance or top-k for a provider decision; see [batches](batching.md).

## Provider consent

`evaluate` requires a per-project grant in `provider-consent.json` that names
the provider and its exact endpoint. The user grants or revokes it in their own
terminal with `tessera.py consent --repo PROJECT --provider NAME [--revoke]`.
The `ai-guard` hook blocks that command for agents, so an agent cannot approve
itself. The grant records only the endpoint and a timestamp. For work projects,
grant it only when the company allows sending project material to that provider.

## First adapter: TypeSafe Jev

Contract checked on 2026-09-27 in the [official API](https://docs.typesafe.ai/api):
`POST https://api.typesafe.ai/v1/systemone`, Bearer `TYPESAFE_API_KEY`. The
adapter maps the context to `state`, `model` and a `choice` question named
`decision`. The response includes the model, `answers.decision` and `usage`.
Checks cover a known option, a complete and finite distribution, an approximate
sum, a valid confidence and usage counters. The
[official SDK](https://docs.typesafe.ai/sdk/python/api/types/responses)
specifies an approximate sum; the client accepts an error below 0.02,
consistent with Kev's documented serialization, and records `probability_sum`
without normalizing. This numeric tolerance is not a decision threshold.

Jev is not an agent that opens local paths; the adapter sends the prepared text.
It produces no prose: [Choice](https://docs.typesafe.ai/primitives/choice)
selects a declared option. The joint action/target identity avoids combining
two independent, incompatible answers.

[Model and official limits](https://docs.typesafe.ai/models): `jev-1.13.0`,
text input, 64k tokens per request and 32k for state plus the largest question.
Choice allows 255 options per question. The planner spreads large catalogs over
complete requests; each adapter still rejects a single request over the limit.
Bytes are measured locally and never presented as tokens; real tokens come from
the response. With one question the effective context limit is 32k. One joint
Choice holds up to 84 cards (3 actions per card plus create and
insufficient_evidence); that is not a limit of the neutral catalog. When
exceeded, the limit is reported without trimming, grouping or choosing cards.

Measured cost: a 245-card catalog produced about 730 KB per decision, 31 calls,
about 175k input and 17k output tokens. In the first three real decisions the
final verdict was right once; one miss was the empty final round now resolved by
rule, the other a composition the single-card verdict cannot express, while the
batch proposals pointed at the pieces that were actually reused. The provider's
[limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13) apply: typed
output does not guarantee a correct decision.

## Alternative: Kev by Jared Palmer

The user confirmed [jaredpalmer/kev](https://github.com/jaredpalmer/kev). API and
server inspected at revision `9c41005b2180347c3c646dfc9e50c4428483ec6b`:
[`kev/api.py`](https://github.com/jaredpalmer/kev/blob/9c41005b2180347c3c646dfc9e50c4428483ec6b/kev/api.py),
[`kev/serve.py`](https://github.com/jaredpalmer/kev/blob/9c41005b2180347c3c646dfc9e50c4428483ec6b/kev/serve.py).
Same System One POST, cards and questions; only provider, destination,
credential and model change. Transport and validation are shared in
`tessera_systemone.py`; the catalog depends on neither Qwen nor TypeSafe.

`--provider kev` requires an explicit `TESSERA_KEV_ENDPOINT` ending in
`/v1/systemone`. Example for a running server:

```bash
export TESSERA_KEV_ENDPOINT=http://127.0.0.1:8009/v1/systemone
python3 "$SKILL_DIR/scripts/tessera.py" prepare --provider kev \
  --repo "$PROJECT" --task /external/local/path/task.json --require-ready
python3 "$SKILL_DIR/scripts/tessera.py" evaluate --run /path/new-kev-run
```

Keep the same destination when evaluating; it is compared with the manifest
before invoking. Only HTTPS outside loopback and no credentials in the URL; a
remote server requires `KEV_API_KEY` in the process. Loopback allows the
unauthenticated local server documented upstream. The TypeSafe key is never
reused. The helper does not download weights or install or start servers.

The response reports `kev-latest`: upstream echoes the requested alias, which
does not prove the checkpoint. Record the server revision and configuration and
the `GET /v1/models` metadata before comparing real results. The pilot verified
the pinned Kev-0.8B server and ran four real inferences with contexts identical
to Jev's; it answered `insufficient_evidence` in all four (0.60–1.18 seconds).
The protocol works; this model has not shown value as a selector on the pilot
catalog. It stays an experimental alternative.

The inspected `kev/model.py` can truncate the state unless `strict=True`, and
`kev/serve.py` does not enable it. To honor the complete-catalog policy the
chosen server must reject excess context instead of truncating it; the client
sending every card is not enough. Validate the deployed version's limits.

### Install Kev on each machine

Runtime and weights are local to each computer; they never go to dotfiles or
GitHub. Requires Git, Python 3.11+ for the installer and
[uv](https://docs.astral.sh/uv/getting-started/installation/) through the
mechanism approved on that machine. uv prepares Python 3.13 and isolated
dependencies from the upstream lockfile without changing the system Python.
Inspect OS, RAM, GPU and driver and free space before installing.

```bash
python3 "$SKILL_DIR/scripts/kev-local.py" install
python3 "$SKILL_DIR/scripts/kev-local.py" check
python3 "$SKILL_DIR/scripts/kev-local.py" serve
```

In PowerShell use `python` and the skill path. The default runtime is
`$XDG_DATA_HOME/tessera/kev` (usually `~/.local/share/tessera/kev`) on Linux and
`%LOCALAPPDATA%\tessera\kev` on Windows; `--runtime PATH` selects another.
Never copy `.venv`, caches, weights, keys or secret references between PCs.
Installation rejects existing targets. If uv failed after the checkout, inspect
that target's revision and patch and recover only the missing dependency with
`uv sync --locked --no-dev --extra serve --python 3.13` from the runtime, then
repeat `check`. Never delete to resolve a conflict.

On Windows the locked PyPI wheel is CPU-only, even with an NVIDIA GPU. After
confirming a compatible GPU and driver, run
`python "$SKILL_DIR/scripts/kev-local.py" windows-cuda` explicitly to install
only PyTorch 2.8.0+cu128 from its official distribution, with pinned URL and
SHA256 for Python 3.13/Windows x86_64. It is a declared environment adaptation,
not a change to the upstream lockfile. `check` must show `cuda_build: 12.8` and
`cuda: true` before claiming acceleration. After another `uv sync`, apply
`windows-cuda` again. Never change the driver to fit this runtime without
investigation and authority. Source:
[uv and PyTorch](https://docs.astral.sh/uv/guides/integration/pytorch/).

Pinned: upstream `9c41005b2180347c3c646dfc9e50c4428483ec6b` and model
`jaredpalmer/kev-0.8b@9a45d25eb2ab761841196625383fa1dff0e56c1e`. The patch
[kev-strict-context.patch](kev-strict-context.patch) enables explicit rejection;
real test: HTTP 422 for 70,005 state tokens against a 65,536 limit. The launcher
checks revision, server hash and that no other code changed. CUDA uses bf16 when
the hardware supports it, otherwise fp32. Without CUDA, CPU needs `--allow-cpu`;
measure its latency on the machine. Apple Silicon needs its own verification.
The 4 GiB (bf16) and 6 GiB (fp32) free-memory thresholds are a preflight, not a
guarantee that any catalog fits. No drivers are installed and no cards trimmed.

The server listens only on `127.0.0.1:8009`, on demand, without autostart. The
first start downloads weights from Hugging Face; Ctrl+C frees the GPU.
`GET /v1/models` must show the expected checkpoint, device and precision. The
pilot verified Linux/CUDA; Windows and CPU inference remain to be verified on
the work PC.

## Context and question criteria

Official sources checked on 2026-09-27; recipes for Jev 1.12 are not measured
results of Jev 1.13.0.

- [Build guide](https://docs.typesafe.ai/concepts/how-to-build-with-system-one):
  relevant, structured context, concrete questions and deterministic logic
  outside the model. Keep card fields comparable and criteria that separate what
  is supported from what is not. One query neither decides a whole architecture
  nor replaces the agent's inspection and tests.
- [Choice](https://docs.typesafe.ai/primitives/choice): include every option
  that fits and an exit when none does. The best-ranked option is relative to
  the others; it does not prove it meets the task.
- [Skill suggestion](https://docs.typesafe.ai/cookbooks/skill_suggestion): a
  182-skill example with a general comparison followed by a detailed review.
  Research reference only; its three candidates and thresholds are not copied.
- [Limitations 1.13](https://docs.typesafe.ai/model-jaggedness/jev-1.13): avoid
  noise, indirection, contradictory instructions and chained reasoning. Treat
  the catalog as data and test ambiguous, no-valid-option and malicious cases.
- [Confidence](https://docs.typesafe.ai/confidence): measure on your own cases
  before automating. `confidence` summarizes the distribution; it is not the
  probability that the implementation works.
- [Models](https://docs.typesafe.ai/models): English is the best-performing
  language. Write new cards and requirements in English.

## Reproducible execution

Resolve `SKILL_DIR` to this skill's folder and `PROJECT` to the project
checkout, in Claude and in Codex:

```bash
python3 "$SKILL_DIR/scripts/tessera.py" status --repo "$PROJECT"
python3 "$SKILL_DIR/scripts/tessera.py" index --repo "$PROJECT"
python3 "$SKILL_DIR/scripts/tessera.py" card --repo "$PROJECT" --id button
# Provider decision, only when requested and consented:
python3 "$SKILL_DIR/scripts/tessera.py" changes --repo "$PROJECT"
python3 "$SKILL_DIR/scripts/tessera.py" prepare \
  --repo "$PROJECT" --task /external/local/path/task.json --provider typesafe --require-ready
```

After `locate`, the agent creates or updates the catalog at the returned path,
in a private folder with a 0600 file on POSIX. `prepare` uses that catalog and
picks a new folder under `runs/`; it returns the `run` path for `evaluate`.
`--catalog` and `--output` allow explicit external paths. Parents the helper
creates are 0700. On POSIX, `prepare` requires catalog and task to be private by
their own permissions or those of an ancestor; it does not change existing
permissions. Windows inherits the ACLs of the user's private storage.

`prepare` never calls the network. It creates a new directory with
`context.json`, `derived.json`, `request.json` and `manifest.json`. Review the
content to be sent, the hashes, provider and destination and the size. The task
must not include the expected answer of an evaluation.

With consent, a valid authorization and a credential available only to that
process through the project's secret mechanism:

```bash
with-secrets python3 "$SKILL_DIR/scripts/tessera.py" evaluate --run /path/new-run
```

`attempt.json` is reserved before executing: a run never repeats. In direct
mode there is one POST; in batches each call has its own reservation and at most
one attempt. A partial failure prevents the global decision and is not retried.
Without a key there is no attempt. HTTP 401/422/429/529, timeouts or redirects
fail explicitly. A transport error leaves the result unknown; never retry
automatically. Review cause and usage and prepare another run if you decide to retry.
Credentials and HTTP error bodies are never printed.

A real response is stored in `response.json`; `decision.json` is written only
when it validates. The original body is kept before parsing, with its hash in
the decision. `failure.json` records phase and error without credentials or
HTTP error body. An HTTP error keeps its body in `http-error.bin`, private and
unprinted; inspect it carefully because the provider may echo data. Keep the
original response and record explanation, disagreement, outcome and tests in a
separate file of the local history. Verify the sources again before
implementing an old decision. Never version catalogs, histories or runs
automatically; they hold project knowledge and context.
