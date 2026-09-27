---
name: verify-web-change
description: Verify a completed Next.js, Nuxt, or Vue change with the repository's real scripts and focused browser checks. Invoke explicitly or from verification-before-completion; do not use to implement the change.
---

# Verify Web Change

1. Inspect instructions, diff, package manager, lockfile, workspace, scripts,
   and affected framework. Use existing check-only commands; never invent a
   package-manager command or run a rewriting formatter without authorization.
2. Run relevant lint, typecheck, targeted tests, build, and smoke checks from
   fastest to slowest. Expand scope when the changed boundary warrants it.
3. For interaction changes, check keyboard access, visible focus, logical order,
   focus restoration, and accessible name, role, and state.
4. For SSR or routing changes, test direct load, reload, and client navigation;
   inspect browser console and server logs. Use safe local or test data only.
5. Compare visual states and viewports with the Figma authority, accepted
   contract, or established local pattern. Do not invent content or aesthetics.
   Check new UI against existing components and their real usage: dialogs,
   typography, variants and tokens as applicable. Flag recreated primitives or
   CSS overrides that bypass a suitable supported component, citing its path
   and the compatibility evidence. Native markup is valid when it is the local
   convention or the existing abstraction is incompatible.
6. Measure before and after when the change plausibly affects performance.

Report commands and observations actually completed, plus every unverified
surface. This skill validates; it does not create a completion claim by itself.
