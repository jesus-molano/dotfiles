# Nuxt 4 Project Scaffold Guide

## Initial Setup

```bash
pnpm dlx nuxi@latest init my-app
cd my-app
```

## Directory Structure Setup

```bash
# Feature-based structure
mkdir -p app/{components/ui,composables,features,layouts,middleware,pages,plugins,utils}
mkdir -p shared/{types,utils}
mkdir -p server/{api,middleware,plugins,utils,routes}
mkdir -p i18n/locales
mkdir -p test/{unit,nuxt,e2e}
mkdir -p docs/{architecture/decisions,guides,api}
```

## Essential Config Files

### nuxt.config.ts
```ts
export default defineNuxtConfig({
  future: { compatibilityVersion: 4 },
  compatibilityDate: '2025-01-01',

  typescript: { strict: true, typeCheck: true },

  modules: [
    '@pinia/nuxt',
    '@nuxtjs/i18n',
    '@nuxt/image',
    '@nuxt/fonts',
    '@nuxt/scripts',
    '@nuxt/test-utils',
    '@vueuse/nuxt',
    'nuxt-security',
    '@nuxtjs/seo',
  ],

  i18n: {
    locales: [
      { code: 'en', file: 'en.json' },
      { code: 'es', file: 'es.json' },
    ],
    defaultLocale: 'en',
    lazy: true,
    langDir: '../i18n/locales',
  },

  routeRules: {
    '/': { prerender: true },
    '/api/**': { cors: true },
  },
})
```

### tsconfig.json
```json
{
  "files": [],
  "references": [
    { "path": "./.nuxt/tsconfig.app.json" },
    { "path": "./.nuxt/tsconfig.server.json" },
    { "path": "./.nuxt/tsconfig.shared.json" },
    { "path": "./.nuxt/tsconfig.node.json" }
  ]
}
```

### vitest.config.ts
```ts
import { defineConfig } from 'vitest/config'
import { defineVitestProject } from '@nuxt/test-utils/config'

export default defineConfig({
  test: {
    projects: [
      { test: { name: 'unit', include: ['test/unit/**/*.test.ts'], environment: 'node' } },
      await defineVitestProject({
        test: { name: 'nuxt', include: ['test/nuxt/**/*.test.ts'], environment: 'nuxt' },
      }),
    ],
  },
})
```

## Feature Module Template

```bash
mkdir -p app/features/{feature-name}/{components,composables,stores,types,__tests__}
touch app/features/{feature-name}/index.ts
```

### Barrel Export Pattern
```ts
// app/features/auth/index.ts
export { LoginForm } from './components/LoginForm.vue'
export { useAuth } from './composables/useAuth'
export type { User, Session } from './types'
```

## Server Route Patterns

### API Proxy
```ts
// server/api/[...].ts
import { joinURL } from 'ufo'
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)
  const path = event.path.replace(/^\/api\//, '')
  return proxyRequest(event, joinURL(config.externalApiUrl, path))
})
```

### Health Check
```ts
// server/routes/health.get.ts
export default defineEventHandler(() => ({ status: 'ok', timestamp: Date.now() }))
```

## Essential Dependencies

```bash
# Core
pnpm add @pinia/nuxt @nuxtjs/i18n @nuxt/image @nuxt/fonts @vueuse/nuxt nuxt-security @nuxtjs/seo

# Dev
pnpm add -D @nuxt/test-utils @nuxt/scripts vitest @biomejs/biome @commitlint/cli @commitlint/config-conventional lefthook playwright
```

## Logging Setup

```ts
// server/utils/logger.ts
import { consola } from 'consola'
export const logger = consola.withTag('server')

// app/composables/useLogger.ts
import { consola } from 'consola'
export function useLogger(tag: string) {
  return consola.withTag(tag)
}
```
