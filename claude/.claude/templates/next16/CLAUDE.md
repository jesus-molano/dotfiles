# Project: {name} — Next.js 16

## Stack
Next.js 16 (React 19, Turbopack, App Router) · TypeScript strict · pnpm · Biome

## Architecture
Feature-based with `src/` directory:

```
src/
├── app/                        # App Router
│   ├── (marketing)/            # Route group — public pages
│   ├── (dashboard)/            # Route group — authenticated
│   ├── api/                    # Route Handlers (BFF proxy)
│   ├── layout.tsx
│   ├── not-found.tsx
│   └── global-error.tsx
├── features/                   # Feature modules (primary pattern)
│   └── {feature}/
│       ├── components/
│       ├── hooks/
│       ├── actions/            # Server Actions ('use server')
│       ├── types/
│       └── index.ts            # Public barrel export
├── shared/
│   ├── ui/                     # Base UI components (no business logic)
│   ├── lib/                    # Utilities
│   └── types/
└── providers/                  # Client providers (when needed)
proxy.ts                        # Auth guards, redirects (replaces middleware.ts)
```

## Conventions
- Server Components by default — push `"use client"` to leaf components only
- `"use cache"` + `cacheLife()` + `cacheTag()` for caching (replaces ISR)
- `"use server"` + Zod validation for mutations (Server Actions)
- React Compiler enabled — no manual `useMemo`/`useCallback`
- Route Handlers as BFF proxy — client never calls external APIs directly
- `proxy.ts` for auth guards/redirects (full Node.js runtime, not Edge)
- Error boundaries: `error.tsx` per segment, `global-error.tsx` at root

## Phased Development
This project uses phased scaffolding. Refer to `project-scaffold.md` for phases.

**CRITICAL: Execute ONE phase at a time. ASK the user before advancing to the next phase.**
Never scaffold everything at once — each phase should be complete and working before moving on.

## Docs
Use Context7 MCP (`resolve-library-id` → `query-docs`) before implementing any Next.js/React API.
Never rely on training data alone for framework-specific code.
