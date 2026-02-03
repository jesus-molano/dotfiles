# Project Instructions — Nuxt 4

## Stack
- Nuxt 4 (Vue 3.5, Nitro, Vite)
- TypeScript strict mode with split configs
- pnpm, Biome, Lefthook, Commitlint
- Vitest + @nuxt/test-utils, Playwright for e2e

## Architecture
Feature-based with `app/` directory (srcDir):

```
app/
├── components/ui/        # Shared base UI components
├── composables/          # Shared composables
├── features/             # Feature modules (THE pattern)
│   └── {feature}/
│       ├── components/
│       ├── composables/
│       ├── stores/       # Pinia setup stores
│       ├── types/
│       ├── __tests__/
│       └── index.ts      # Public barrel export
├── layouts/
├── middleware/
├── pages/
├── plugins/
└── utils/
shared/                   # Shared between app/ and server/
├── types/
└── utils/
server/
├── api/
├── middleware/
├── plugins/
├── utils/
└── routes/
```

## Key Patterns

### Data Fetching
- `useAsyncData` / `useFetch` with unique string keys
- shallowRef by default (Nuxt 4) — opt into deep only when needed
- Server routes proxy external APIs — never expose keys client-side

### State
- Pinia setup stores (`defineStore` with setup syntax)
- Server state in useAsyncData, NOT in stores
- Local ref/reactive for component state

### Components
- `<script setup lang="ts">` always
- defineProps with TypeScript interface
- defineEmits with typed events
- Scoped styles, slots for composition
- onUnmounted / onWatcherCleanup for cleanup

### Error Handling
- `createError({ status, statusText, fatal })` — Nuxt 4 uses status/statusText
- `error.vue` for global error page
- `onErrorCaptured` for component error boundaries

### Rendering
- routeRules for hybrid rendering:
  - `prerender: true` for static pages
  - `isr: seconds` for incremental static regeneration
  - `swr: seconds` for stale-while-revalidate
  - `ssr: false` for SPA sections

### Modules
```ts
modules: [
  '@pinia/nuxt', '@nuxtjs/i18n', '@nuxt/image', '@nuxt/fonts',
  '@nuxt/scripts', '@nuxt/test-utils', '@vueuse/nuxt',
  'nuxt-security', '@nuxtjs/seo',
]
```

### i18n
- @nuxtjs/i18n v10 with lazy-loaded locales
- Locale files in `i18n/locales/` (outside app/)

### Testing
- Unit tests: `test/unit/` (node environment)
- Nuxt tests: `test/nuxt/` (nuxt environment, mountSuspended)
- E2E: `test/e2e/` (Playwright)

### Memory Leak Prevention
- onWatcherCleanup for AbortController in watchers
- useEventListener from VueUse (auto-cleanup)
- onUnmounted for manual cleanup
- Never store component refs at module level
