---
name: perf-audit
description: Audit project for performance issues across Vue/Nuxt and React/Next.js
disable-model-invocation: true
context: fork
agent: Explore
---

# Performance Audit

Auto-detect framework and audit accordingly.

## Vue / Nuxt 4 Checks

### Reactivity
- [ ] `shallowRef` used for large objects/arrays (Nuxt 4 default for useAsyncData)
- [ ] `computed` for derived state (not inline calculations in template)
- [ ] No reactive() for simple primitives — use ref()
- [ ] VueUse composables replacing manual implementations

### Nuxt-Specific
- [ ] `<NuxtImage>` / `<NuxtPicture>` for all images (not raw `<img>`)
- [ ] Route rules configured (ISR/SWR/SSG/SPA per route)
- [ ] Lazy hydration for below-fold components (`<LazyComponent>`)
- [ ] `useAsyncData`/`useFetch` with proper keys (no duplicate requests)
- [ ] Server routes for external API calls (not client-side fetch to third parties)
- [ ] `definePageMeta({ middleware })` not global middleware for auth

### Build
- [ ] Unused modules removed from `nuxt.config.ts`
- [ ] `routeRules` prerender for static pages

## React / Next.js 16 Checks

### Caching & Rendering
- [ ] `"use cache"` directive on cacheable server components/functions
- [ ] `cacheLife()` and `cacheTag()` configured appropriately
- [ ] React Compiler compatibility (no manual useMemo/useCallback needed)
- [ ] Server Components as default — `"use client"` only when necessary
- [ ] Proper Server/Client component boundaries (client components at leaves)

### Data Fetching
- [ ] TanStack Query for client-side server state (not Zustand/Redux)
- [ ] Server Component prefetch → HydrationBoundary pattern
- [ ] No fetch waterfalls (parallel data loading)
- [ ] `revalidateTag` / `revalidatePath` for cache invalidation

### Build
- [ ] Turbopack in use (default in 16)
- [ ] `serverExternalPackages` for Node.js-only deps
- [ ] Dynamic imports for heavy client components

## Shared Checks

### Bundle
- [ ] No moment.js — use dayjs or date-fns
- [ ] No lodash (full) — use es-toolkit or lodash-es with tree-shaking
- [ ] Barrel files not re-exporting entire modules
- [ ] Dynamic imports for routes and heavy components
- [ ] CSS-in-JS avoided (use CSS Modules or scoped styles)

### Memory Leaks
- [ ] Event listeners cleaned up on unmount
- [ ] AbortController for fetches in effects/watchers
- [ ] Intervals/timeouts cleared
- [ ] No module-level component refs

### Assets
- [ ] Images: WebP/AVIF with responsive sizes
- [ ] Fonts: preloaded, subset, font-display: swap
- [ ] Third-party scripts: async/defer or Nuxt Scripts / next/script

## Output Format

Report findings grouped by severity:
1. **Critical** — Measurable performance impact, fix immediately
2. **Warning** — Potential impact, should address
3. **Opportunity** — Optimization opportunities

Each finding: `file:line — issue — recommendation`
