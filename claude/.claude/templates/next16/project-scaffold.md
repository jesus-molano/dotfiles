# Next.js 16 — Phased Scaffold

**CRITICAL: Execute ONE phase at a time. ASK the user before advancing to the next phase.**
Each phase must be complete and verified before moving on.

---

## Phase 0: Foundation

**When:** Project initialization.

### Steps

1. Initialize:
```bash
pnpm create next-app@latest {name} --typescript --app --src-dir --turbopack
cd {name}
```

2. Configure `next.config.ts`:
```ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  reactCompiler: true,
}

export default nextConfig
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
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "typecheck": "tsc --noEmit"
  }
}
```

6. Create directory structure:
```bash
mkdir -p src/{features,shared/{ui,lib,types},providers}
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
mkdir -p src/features/{feature}/{components,hooks,types}
touch src/features/{feature}/index.ts
```

2. Barrel export pattern:
```ts
// src/features/posts/index.ts
export { PostList } from './components/PostList'
export { usePostFilters } from './hooks/usePostFilters'
export type { Post, PostFilters } from './types'
```

3. Server Component with data fetching (default — no directive needed):
```tsx
// src/features/posts/components/PostList.tsx
import { cacheLife, cacheTag } from 'next/cache'

export async function PostList() {
  'use cache'
  cacheLife('hours')
  cacheTag('posts')

  const posts = await fetch(`${process.env.BACKEND_URL}/posts`).then(r => r.json())

  return (
    <ul>
      {posts.map((post: Post) => (
        <li key={post.id}>{post.title}</li>
      ))}
    </ul>
  )
}
```

4. Route Handler as BFF proxy (if the feature needs external data from client):
```ts
// src/app/api/posts/route.ts
import { NextResponse } from 'next/server'

export async function GET() {
  const res = await fetch(`${process.env.BACKEND_URL}/posts`, {
    headers: { Authorization: `Bearer ${process.env.API_SECRET}` },
  })

  if (!res.ok) {
    return NextResponse.json(
      { error: 'Failed to fetch posts' },
      { status: res.status },
    )
  }

  return NextResponse.json(await res.json())
}
```

5. Page as thin wrapper:
```tsx
// src/app/(marketing)/page.tsx
import { PostList } from '@/features/posts'

export default function HomePage() {
  return (
    <main>
      <h1>Latest Posts</h1>
      <PostList />
    </main>
  )
}
```

6. Error boundary for the route segment:
```tsx
// src/app/(marketing)/error.tsx
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={() => reset()}>Try again</button>
    </div>
  )
}
```

**Done when:** Feature renders with real data. Server Components fetch data directly. Error boundary catches failures.

---

## Phase 2: Server Actions & Forms

**When:** Feature needs mutations (create, update, delete).

### Steps

1. Install Zod:
```bash
pnpm add zod
```

2. Server Action with Zod validation:
```ts
// src/features/posts/actions/createPost.ts
'use server'

import { z } from 'zod'
import { revalidateTag } from 'next/cache'

const CreatePostSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200),
  content: z.string().min(1, 'Content is required'),
})

export type CreatePostState = {
  errors?: {
    title?: string[]
    content?: string[]
  }
  message?: string
} | undefined

export async function createPost(prevState: CreatePostState, formData: FormData) {
  const result = CreatePostSchema.safeParse({
    title: formData.get('title'),
    content: formData.get('content'),
  })

  if (!result.success) {
    return { errors: result.error.flatten().fieldErrors }
  }

  const res = await fetch(`${process.env.BACKEND_URL}/posts`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${process.env.API_SECRET}`,
    },
    body: JSON.stringify(result.data),
  })

  if (!res.ok) {
    return { message: 'Failed to create post' }
  }

  revalidateTag('posts')
}
```

3. Client form with `useActionState`:
```tsx
// src/features/posts/components/CreatePostForm.tsx
'use client'

import { useActionState } from 'react'
import { createPost } from '../actions/createPost'

export function CreatePostForm() {
  const [state, action, pending] = useActionState(createPost, undefined)

  return (
    <form action={action}>
      <div>
        <label htmlFor="title">Title</label>
        <input id="title" name="title" />
        {state?.errors?.title && <p>{state.errors.title[0]}</p>}
      </div>

      <div>
        <label htmlFor="content">Content</label>
        <textarea id="content" name="content" />
        {state?.errors?.content && <p>{state.errors.content[0]}</p>}
      </div>

      {state?.message && <p>{state.message}</p>}

      <button type="submit" disabled={pending}>
        {pending ? 'Creating...' : 'Create Post'}
      </button>
    </form>
  )
}
```

**Done when:** Form submits, validates on server, shows field errors, and revalidates cached data on success.

---

## Phase 3: Testing

**When:** There's actual business logic and components worth testing.

### Steps

1. Install:
```bash
pnpm add -D vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom @testing-library/user-event vite-tsconfig-paths
```

2. Create `vitest.config.mts`:
```ts
import react from '@vitejs/plugin-react'
import tsconfigPaths from 'vite-tsconfig-paths'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [tsconfigPaths(), react()],
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    include: ['src/**/*.test.{ts,tsx}'],
  },
})
```

3. Create test setup:
```ts
// src/test/setup.ts
import '@testing-library/jest-dom/vitest'
```

4. Add scripts:
```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

5. Test file naming convention (co-located with source):
   - `*.test.ts` — pure logic (hooks, utils, Server Actions as plain functions)
   - `*.test.tsx` — component tests with @testing-library/react

6. Component test example:
```tsx
// src/features/posts/components/CreatePostForm.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { CreatePostForm } from './CreatePostForm'

describe('CreatePostForm', () => {
  it('renders form fields', () => {
    render(<CreatePostForm />)
    expect(screen.getByLabelText('Title')).toBeInTheDocument()
    expect(screen.getByLabelText('Content')).toBeInTheDocument()
  })
})
```

7. Server Action test example:
```ts
// src/features/posts/actions/createPost.test.ts
import { describe, expect, it } from 'vitest'

describe('CreatePostSchema', () => {
  it('rejects empty title', () => {
    const result = CreatePostSchema.safeParse({ title: '', content: 'body' })
    expect(result.success).toBe(false)
  })
})
```

**Done when:** `pnpm test` passes. Core business logic and key components have tests.

---

## Phase 4: Client State

**When:** Server Components + Server Actions aren't enough. Interactive UI needs shared client state.

> Most Next.js 16 apps should NOT need this phase. Server Components handle most data fetching.

### Steps

1. Install (only what's needed):
```bash
# Zustand — if components share client-only state (UI state, filters, modals)
pnpm add zustand

# TanStack Query — if client components need to refetch/poll server data
pnpm add @tanstack/react-query
```

2. Zustand store (client-only state):
```ts
// src/features/{feature}/hooks/use{Feature}Store.ts
import { create } from 'zustand'

interface FiltersState {
  search: string
  setSearch: (search: string) => void
}

export const useFiltersStore = create<FiltersState>((set) => ({
  search: '',
  setSearch: (search) => set({ search }),
}))
```

3. TanStack Query provider (only if using TanStack Query):
```tsx
// src/providers/query-provider.tsx
'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () => new QueryClient({ defaultOptions: { queries: { staleTime: 60_000 } } }),
  )
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
}
```

4. Add provider to root layout:
```tsx
// src/app/layout.tsx
import { QueryProvider } from '@/providers/query-provider'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <QueryProvider>{children}</QueryProvider>
      </body>
    </html>
  )
}
```

**Done when:** Client state is minimal. Server data stays in Server Components or Server Actions.

---

## Phase 5: Auth & Proxy

**When:** Routes need authentication guards or request-level logic.

### Steps

1. Create `proxy.ts` at project root (Next.js 16 replaces `middleware.ts`):
```ts
// proxy.ts
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

2. Create route groups for authenticated sections:
```bash
mkdir -p src/app/\(dashboard\)
mkdir -p src/app/\(marketing\)
```

**Done when:** Protected routes redirect unauthenticated users. Public routes are unaffected.

---

## Phase 6: i18n, Images, SEO, Security

**When:** Pre-production hardening.

### i18n
```bash
pnpm add next-intl
```
- Configure with App Router integration
- Extract hardcoded strings to message files
- Consult Context7 for current `next-intl` setup

### Images
- Use `<Image>` from `next/image` — never raw `<img>`
- Set `width`, `height`, or `fill` for layout stability
- Use `priority` for above-the-fold images

### SEO
- Use `generateMetadata` or `metadata` export per page
- `sitemap.ts` and `robots.ts` for crawlers

### Security
- Configure security headers in `next.config.ts`:
```ts
const nextConfig: NextConfig = {
  headers: async () => [
    {
      source: '/(.*)',
      headers: [
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
      ],
    },
  ],
}
```

**Done when:** Metadata renders correctly. Images optimized. Security headers verified.

---

## Phase 7: E2E & CI

**When:** Features are stable enough for integration testing.

### Steps

1. Install Playwright:
```bash
pnpm add -D @playwright/test
pnpm exec playwright install --with-deps chromium
```

2. Create E2E tests in `tests/e2e/` for critical user flows.

3. Copy `ci-workflow.yml` from shared templates to `.github/workflows/ci.yml`.
   - Update artifact path from `.output/` to `.next/` for Next.js.

4. Verify CI pipeline runs: lint → typecheck → test → build → e2e.

**Done when:** CI pipeline green on main. Critical user flows covered by E2E tests.
