# Exhaustive batch decisions

The unit of coverage is a complete decision, not an HTTP request. Every card
reaches the provider in the first round exactly once, with its full contract,
constraints and references. Tests stay out of the whole flow. There is no
preselection by similarity, category, ranking or top-k.

`prepare --require-ready` keeps the direct protocol when the context fits.
Otherwise `request.json` stores an `exhaustive-batches-v1` plan instead of one
HTTP body. The plan orders cards by stable ID and never splits the three
actions of one card. Each request allows up to 255 options and 24,000
serialized bytes. That conservative byte budget is not a token count and does
not replace the server limit; `token_count` stays null before a call. Never
trim contracts or retry after a context rejection.

Each batch can choose one action/card pair, `create` (no card in THAT batch
fits) or `insufficient_evidence`. The coordinator waits for every batch to
succeed. Then the same provider compares the selected proposals, keeping their
full action and contract, with create and abstain in every comparison, and
repeats bounded rounds if needed. Probabilities from different questions are
never added or compared. Proposals the provider discards stay in the history.

When no batch proposes a card, the coordinator decides by rule without another
call: unanimous `create` means no card fits, and any `insufficient_evidence`
means abstention. The result is marked `decided_by: coordinator` and records
the rule; it is never attributed to the provider. Asking the provider to
compare an empty set costs a call and returns no information.

Earlier uncertainty prevents a global create: a concrete supported proposal or
abstention is accepted. If the provider still returns `create` at the end
despite that uncertainty, the run fails instead of inventing another answer.
The final confidence belongs only to that final comparison, never to the whole
catalog or an aggregate. The agent always verifies the choice.

Before the network, the plan checks that every card fits whole and that two
finalists fit together. It includes the maximum number of calls (up to 128),
sized so that even pairwise reductions have room. A plan over those limits
fails explicitly. It never switches provider or edits the catalog to fit.

## Execution and traceability

`evaluate` checks the plan by rebuilding it from the context, hashes, revision
and local evidence. It keeps provider and destination for the whole run and
checks before each call and at the end that the checkout and the ready catalog
are still current. Each call is stored in `calls/0000/` and onward with request,
prior `attempt.json` reservation, original response and validated result with
hashes. On Windows it uses extended Win32 paths for nested artifacts, without
changing the machine's long-path policy. A preexisting `calls` directory,
including a link, is rejected before any request. The global `decision.json` is
written only after all rounds finish.

The global result keeps evaluated IDs, all call results, the real total usage,
the final answer, provenance and, when the task carried one, the blind
`agent_choice` and whether it agreed. A failed HTTP call, timeout, invalid
response or checkout change stops the run. Partial history is kept; the run
cannot be resumed or repeated automatically. Fixing the cause and preparing a
new run is an explicit step.

The manifest shows the initial batches and the maximum call count: review them
before sending material. `prepare` never calls the provider. Compatible direct
runs keep their protocol; an incompatible old plan is rejected, not rewritten.
Kev shares the planner but keeps its own adapter and credential; its quality is
not assumed equal to Jev's.

## Quality and limits

Every card is considered before proposals are chosen, but a local winner can
depend on which other cards share its batch. Ordering by ID gives
reproducibility, not semantic invariance. The output is one action on one card,
so a task that composes several existing pieces (for example a card component,
an API client and a section header) is only partly expressed by the verdict;
the batch proposals carry that signal. To evaluate quality, use reuse, modify,
wrap, create and abstain cases, vary the grouping and measure accuracy,
abstentions, tokens and latency, together with agreement against the blind
agent choice (`tessera.py report`). Never present tests with a simulated
provider as evidence of model quality.

Design references: [TypeSafe skill suggestion](https://docs.typesafe.ai/cookbooks/skill_suggestion)
proposes blocks and a later comparison for larger catalogs;
[Choice](https://docs.typesafe.ai/primitives/choice) limits each question to 255
options. They are background for the design, not Tessera results.
