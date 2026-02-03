# Next.js 16 Project Scaffold Guide

## Initial Setup

```bash
pnpm create next-app@latest my-app --typescript --app --src-dir --turbopack
cd my-app
```

## Directory Structure Setup

```bash
# Feature-based structure
mkdir -p src/{features,shared/{ui,lib,types},providers,config}
mkdir -p src/app/{api,\(marketing\),\(dashboard\)}
mkdir -p tests/{setup.ts,e2e}
mkdir -p docs/{architecture/decisions,guides,api}
```

## Essential Config Files

### next.config.ts
```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  reactCompiler: true,
  cacheComponents: true,
  serverExternalPackages: ['pino', 'pino-pretty'],
}

export default nextConfig
```

### proxy.ts
```ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  const session = request.cookies.get('session')
  if (!session && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
}
```

### vitest.config.mts
```ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths(), react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './tests/setup.ts',
    include: ['src/**/*.test.{ts,tsx}'],
  },
})
```

### instrumentation.ts
```ts
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // Server-side initialization
    const { logger } = await import('./src/shared/lib/logger')
    logger.info('Server started')
  }
}
```

## Feature Module Template

```bash
mkdir -p src/features/{feature-name}/{components,hooks,actions,api,types,__tests__}
touch src/features/{feature-name}/index.ts
```

### Barrel Export Pattern
```ts
// src/features/auth/index.ts
export { LoginForm } from './components/LoginForm'
export { useAuth } from './hooks/useAuth'
export type { User, Session } from './types'
```

## Key Patterns

### API Proxy Route Handler
```ts
// src/app/api/[...path]/route.ts
import { NextRequest, NextResponse } from 'next/server'

const BACKEND = process.env.BACKEND_URL!

export async function GET(request: NextRequest) {
  const path = request.nextUrl.pathname.replace('/api/', '')
  const res = await fetch(`${BACKEND}/${path}`, {
    headers: { Authorization: `Bearer ${process.env.API_SECRET}` },
  })
  return NextResponse.json(await res.json(), { status: res.status })
}
```

### Server Action with Validation
```ts
// src/features/auth/actions/auth.ts
'use server'
import { z } from 'zod'
import { revalidateTag } from 'next/cache'

const Schema = z.object({ email: z.string().email(), password: z.string().min(8) })

export async function login(prevState: unknown, formData: FormData) {
  const result = Schema.safeParse(Object.fromEntries(formData))
  if (!result.success) return { errors: result.error.flatten().fieldErrors }
  // authenticate...
  revalidateTag('session')
}
```

### "use cache" Component
```tsx
import { cacheLife, cacheTag } from 'next/cache'

export default async function FeaturedProducts() {
  'use cache'
  cacheLife('hours')
  cacheTag('featured-products')
  const products = await fetchFeaturedProducts()
  return <ProductGrid products={products} />
}
```

### Typed Env Vars
```ts
// src/shared/lib/env.ts
import { createEnv } from '@t3-oss/env-nextjs'
import { z } from 'zod'

export const env = createEnv({
  server: { DATABASE_URL: z.string().url(), API_SECRET: z.string().min(1) },
  client: { NEXT_PUBLIC_API_URL: z.string().url() },
  experimental__runtimeEnv: { NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL },
  emptyStringAsUndefined: true,
})
```

## Essential Dependencies

```bash
# Core
pnpm add @tanstack/react-query zustand next-intl zod @t3-oss/env-nextjs pino

# Dev
pnpm add -D vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom vite-tsconfig-paths @biomejs/biome @commitlint/cli @commitlint/config-conventional lefthook playwright pino-pretty
```

## Logging Setup

```ts
// src/shared/lib/logger.ts
import pino from 'pino'

export const logger = process.env.NODE_ENV === 'production'
  ? pino({ level: 'warn' })
  : pino({ transport: { target: 'pino-pretty', options: { colorize: true } }, level: 'debug' })
```

## Providers Setup

```tsx
// src/providers/index.tsx
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: { queries: { staleTime: 60 * 1000 } },
  }))
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
}
```
