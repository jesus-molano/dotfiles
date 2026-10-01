---
name: debug-web-flow
description: Reproduce and diagnose a complete Next.js, Nuxt or Vue flow with browser, console, network, logs and code. Use when a failure involves UI, SSR, hydration, navigation, forms, authentication, APIs or async state across browser and server; not for isolated generic bugs.
---

# Debug a Web Flow

## Reproduce before changing

1. Read the instructions, Git state and the steps the user gave. If the failure
   does not cross a web boundary, use `systematic-debugging` instead.
2. Detect the framework, package manager and the repository's real commands.
3. Use a local, test or staging environment with disposable data. Never run
   authentication, form or persistence flows against production without
   explicit user authorization.
4. Start only the services you need. Record URL, test data and the observed
   result without revealing secrets.
5. Reproduce with minimal steps and capture the relevant console, network and
   logs, using `playwright-cli` or the client's built-in browser.

If the request is diagnosis only, do not edit code.

## Isolate the cause

- Trace from the interaction to state, request, handler and persistence.
- Separate client, server, SSR, hydration, cache and middleware.
- Form one testable hypothesis at a time and look for evidence that could refute it.
- Do not blame the framework or a dependency without confirming the version and
  the executed path.

## Fix when authorized

Apply the smallest change that removes the cause, keep unrelated work and add a
proportional regression test. No side refactors, and never weaken validation to
make a test pass.

## Verify

Repeat the original flow and at least one negative or edge case. Run the
relevant existing lint, type, test and build scripts. Report root cause,
evidence, changed files, checks and any open risk.
