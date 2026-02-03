# Project Instructions — Next.js 16

## Stack
- Next.js 16 (React 19, Turbopack, App Router)
- TypeScript strict mode
- pnpm, Biome, Lefthook, Commitlint
- Vitest + @testing-library/react, Playwright for e2e

## Architecture
Feature-based with App Router:

```
src/
├── app/                        # App Router
│   ├── (marketing)/            # Route group — public
│   ├── (dashboard)/            # Route group — authenticated
│   ├── api/                    # Route Handlers
│   ├── layout.tsx
│   ├── not-found.tsx
│   └── global-error.tsx
├── features/                   # Feature modules (THE pattern)
│   └── {feature}/
│       ├── components/
│       ├── hooks/
│       ├── actions/            # 'use server' Server Actions
│       ├── api/                # API client functions
│       ├── types/
│       ├── __tests__/
│       └── index.ts            # Public barrel export
├── shared/
│   ├── ui/                     # Base UI components
│   ├── lib/                    # Utilities (api-client, logger, env)
│   └── types/
├── providers/                  # Client providers
└── config/
```

## Key Patterns

### Caching — "use cache" (replaces ISR)
- `"use cache"` directive on cacheable server components/functions
- `cacheLife('hours' | 'days' | 'weeks' | 'max')` for TTL
- `cacheTag('tag')` for targeted revalidation
- `revalidateTag('tag')` in Server Actions

### Server Components (Default)
- All components are Server Components unless marked `"use client"`
- Push `"use client"` to leaf components (forms, interactive elements)
- Server Components can fetch data directly, no useEffect needed

### Server Actions
- `"use server"` directive for mutations
- Zod validation for form data
- `useActionState` for form state management
- `revalidateTag` / `revalidatePath` for cache invalidation

### State
- Zustand for client-side global state (minimal)
- TanStack Query for server state (client components)
- Server Component prefetch → HydrationBoundary for SSR

### proxy.ts (replaces middleware.ts)
- Full Node.js runtime (not Edge)
- Auth guards, i18n routing, redirects

### Error Handling
- `error.tsx` at route segment level
- `global-error.tsx` for root errors
- `not-found.tsx` for 404 pages
- Server Actions return typed error objects

### Logging
- pino for server, pino-pretty for dev
- `serverExternalPackages: ['pino', 'pino-pretty']`

### Typed Env
- @t3-oss/env-nextjs for runtime-validated env vars

### Testing
- Vitest + @testing-library/react for components
- Server Actions tested as plain async functions
- Playwright for e2e

### React Compiler
- `reactCompiler: true` in next.config.ts
- Eliminates manual useMemo/useCallback
- Ensure code is Compiler-compatible (no mutating refs during render)

### Memory Leak Prevention
- useEffect cleanup returns for subscriptions
- AbortController for fetch in effects
- Cleanup intervals/timeouts in useEffect returns
