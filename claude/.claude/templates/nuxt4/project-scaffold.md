# Nuxt 4 — Phased Scaffold

**CRITICAL: Execute ONE phase at a time. ASK the user before advancing to the next phase.**
Each phase must be complete and verified before moving on.

---

## Phase 0: Foundation

**When:** Project initialization.

### Steps

1. Initialize:
```bash
pnpm dlx nuxi@latest init {name}
cd {name}
```

2. Configure `nuxt.config.ts`:
```ts
export default defineNuxtConfig({
  future: { compatibilityVersion: 4 },
  compatibilityDate: '2025-05-01',
  typescript: { strict: true, typeCheck: 'build' },

  runtimeConfig: {
    // Server-only — populated from NUXT_API_SECRET env var
    apiSecret: '',
    externalApiBase: '',
    public: {
      // Client + server — populated from NUXT_PUBLIC_APP_NAME env var
      appName: '',
    },
  },
})
```

3. Copy shared configs from template:
   - `biome.json` → project root
   - `lefthook.yml` → project root
   - `commitlint.config.mjs` → project root

4. Install dev tooling:
```bash
pnpm add -D @biomejs/biome @commitlint/cli @commitlint/config-conventional lefthook
pnpm lefthook install
```

5. Add scripts to `package.json`:
```json
{
  "scripts": {
    "dev": "nuxt dev",
    "build": "nuxt build",
    "preview": "nuxt preview",
    "typecheck": "vue-tsc --noEmit"
  }
}
```

6. Create directory structure:
```bash
mkdir -p app/{components/ui,composables,features,layouts,middleware,pages,plugins,utils}
mkdir -p shared/{types,utils}
mkdir -p server/{api,middleware,utils,routes}
```

7. Create `.nvmrc` with current LTS version.

8. Create `.env.example` documenting required env vars (never commit `.env`).

**Done when:** `pnpm dev` runs, `pnpm biome check .` passes, a test commit is validated by lefthook.

---

## Phase 1: First Feature

**When:** User defines the first real feature to build.

### Steps

1. Create the feature module:
```bash
mkdir -p app/features/{feature}/{components,composables,types}
touch app/features/{feature}/index.ts
```

2. Barrel export pattern:
```ts
// app/features/auth/index.ts
export { default as LoginForm } from './components/LoginForm.vue'
export { useAuth } from './composables/useAuth'
export type { User, Session } from './types'
```

3. BFF server route (if the feature needs external data):
```ts
// server/api/[resource].get.ts
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)
  const id = getRouterParam(event, 'resource')

  const data = await $fetch(`${config.externalApiBase}/resource/${id}`, {
    headers: { Authorization: `Bearer ${config.apiSecret}` },
  })

  return data
})
```

4. Page as thin wrapper:
```vue
<!-- app/pages/index.vue -->
<script setup lang="ts">
import { SomeFeatureComponent } from '~/features/some-feature'
</script>

<template>
  <div>
    <SomeFeatureComponent />
  </div>
</template>
```

5. Data fetching in components:
```vue
<script setup lang="ts">
// SSR/initial load — always useFetch or useAsyncData
const { data, status, error } = await useFetch('/api/resource')

// Handle all states in template: loading, error, empty, data
</script>

<template>
  <div v-if="status === 'pending'">Loading...</div>
  <div v-else-if="error">{{ error.message }}</div>
  <div v-else-if="!data">No data</div>
  <div v-else>{{ data }}</div>
</template>
```

**Done when:** Feature works end-to-end with real data flowing through BFF. No direct external API calls from client.

---

## Phase 2: State Management

**When:** Multiple components need to share state that isn't just server data.

> If the state is server data, keep it in `useAsyncData`/`useFetch` — don't duplicate in stores.

### Steps

1. Install:
```bash
pnpm add @pinia/nuxt
```

2. Add to `nuxt.config.ts` modules:
```ts
modules: ['@pinia/nuxt']
```

3. Setup store pattern:
```ts
// app/features/{feature}/stores/use{Feature}Store.ts
export const useFeatureStore = defineStore('feature', () => {
  const items = ref<Item[]>([])
  const isEmpty = computed(() => items.value.length === 0)

  function addItem(item: Item) {
    items.value.push(item)
  }

  return { items, isEmpty, addItem }
})
```

**Done when:** Shared state flows correctly between components. Server state stays in data-fetching layer.

---

## Phase 3: Testing

**When:** There's actual business logic and components worth testing.

### Steps

1. Install:
```bash
pnpm add -D @nuxt/test-utils vitest
```

2. Create `vitest.config.ts`:
```ts
import { defineConfig } from 'vitest/config'
import { defineVitestProject } from '@nuxt/test-utils/config'

export default defineConfig({
  test: {
    projects: [
      {
        test: {
          name: 'unit',
          include: [
            'app/**/*.test.ts',
            'shared/**/*.test.ts',
            'server/**/*.test.ts',
          ],
          environment: 'node',
        },
      },
      await defineVitestProject({
        test: {
          name: 'nuxt',
          include: ['app/**/*.nuxt.test.ts'],
          environment: 'nuxt',
        },
      }),
    ],
  },
})
```

3. Add scripts:
```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

4. Test file naming convention (co-located with source):
   - `*.test.ts` — unit tests (pure logic: composables, utils, server handlers)
   - `*.nuxt.test.ts` — component tests needing Nuxt runtime (`mountSuspended`)

5. Unit test example:
```ts
// app/features/auth/composables/useAuth.test.ts
import { describe, expect, it } from 'vitest'

describe('useAuth', () => {
  it('validates email format', () => {
    expect(isValidEmail('user@example.com')).toBe(true)
    expect(isValidEmail('invalid')).toBe(false)
  })
})
```

6. Component test example:
```ts
// app/features/auth/components/LoginForm.nuxt.test.ts
import { mountSuspended } from '@nuxt/test-utils/runtime'
import { describe, expect, it } from 'vitest'
import LoginForm from './LoginForm.vue'

describe('LoginForm', () => {
  it('renders the form', async () => {
    const wrapper = await mountSuspended(LoginForm)
    expect(wrapper.find('form').exists()).toBe(true)
  })
})
```

**Done when:** `pnpm test` passes. Core business logic and key components have tests.

---

## Phase 4: i18n

**When:** UI has user-facing text that needs translation or localization.

### Steps

1. Install:
```bash
pnpm add @nuxtjs/i18n
```

2. Configure in `nuxt.config.ts`:
```ts
modules: ['@nuxtjs/i18n'],
i18n: {
  locales: [
    { code: 'en', file: 'en.json' },
    { code: 'es', file: 'es.json' },
  ],
  defaultLocale: 'en',
  lazy: true,
  langDir: '../i18n/locales',
},
```

3. Create locale files:
```bash
mkdir -p i18n/locales
```

4. Replace hardcoded strings with `$t('key')` or `t('key')` in `<script setup>`.

**Done when:** App renders correctly in all configured languages. Locale switching works.

---

## Phase 5: Images, SEO & Security

**When:** Pre-production hardening.

### Images
```bash
pnpm add @nuxt/image
```
- Use `<NuxtImg>` instead of `<img>` — `format="webp"`, `loading="lazy"`
- Add to modules in `nuxt.config.ts`

### SEO
```bash
pnpm add @nuxtjs/seo
```
- Use `useSeoMeta()` per page (not legacy `useHead` for meta)
- Add to modules in `nuxt.config.ts`

### Security
```bash
pnpm add nuxt-security
```
- Adds default security headers (HSTS, CSP, X-Frame-Options, etc.)
- Review and customize in `nuxt.config.ts` under `security` key
- Sanitize any `v-html` with DOMPurify

### Fonts
```bash
pnpm add @nuxt/fonts
```
- Auto-optimizes font loading
- Add to modules in `nuxt.config.ts`

**Done when:** Lighthouse scores acceptable. Security headers verified. No `<img>` tags in codebase.

---

## Phase 6: E2E & CI

**When:** Features are stable enough for integration testing.

### Steps

1. Install Playwright:
```bash
pnpm add -D @playwright/test
pnpm exec playwright install --with-deps chromium
```

2. Create E2E tests in `test/e2e/` for critical user flows.

3. Copy `ci-workflow.yml` from shared templates to `.github/workflows/ci.yml`.

4. Verify CI pipeline runs: lint → typecheck → test → build → e2e.

**Done when:** CI pipeline green on main. Critical user flows covered by E2E tests.
