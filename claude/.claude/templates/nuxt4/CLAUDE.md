# Project: {name} — Nuxt 4

## Stack
Nuxt 4 (Vue 3.5, Nitro, Vite) · TypeScript strict · pnpm · Biome

## Architecture
Feature-based with `app/` as srcDir (Nuxt 4 default):

```
app/
├── components/ui/        # Shared dumb components (no business logic)
├── composables/          # Shared composables
├── features/             # Feature modules (primary pattern)
│   └── {feature}/
│       ├── components/
│       ├── composables/
│       ├── types/
│       └── index.ts      # Public barrel export
├── layouts/
├── middleware/
├── pages/                # Thin wrappers — orchestrate, don't implement
├── plugins/
└── utils/
shared/                   # Shared types/utils between app/ and server/
├── types/
└── utils/
server/
├── api/                  # BFF proxy — client NEVER calls external APIs
├── middleware/
├── utils/
└── routes/
```

## Conventions
- `<script setup lang="ts">` always
- `defineProps<T>()` with interface, `defineEmits<T>()`
- `useRuntimeConfig()` for env access — NEVER `process.env` or `import.meta.env`
- Components < 150 lines
- Barrel exports (`index.ts`) only at feature boundaries
- Trust Nuxt auto-imports — don't explicitly import `ref`, `computed`, `useFetch`

## Phased Development
This project uses phased scaffolding. Refer to `project-scaffold.md` for phases.

**CRITICAL: Execute ONE phase at a time. ASK the user before advancing to the next phase.**
Never scaffold everything at once — each phase should be complete and working before moving on.

## Docs
Use Context7 MCP (`resolve-library-id` → `query-docs`) before implementing any Nuxt/Vue API.
Never rely on training data alone for framework-specific code.
