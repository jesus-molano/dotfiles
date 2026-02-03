---
description: Frontend component and state management patterns
globs:
  - "**/*.vue"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/components/**"
  - "**/composables/**"
  - "**/hooks/**"
---

# Frontend Patterns

## Component Design
- Props down, events/callbacks up. Never mutate props
- Single responsibility — one reason to change per component
- Slots (Vue) / children+render props (React) for composition
- Headless/renderless patterns for complex reusable logic

## State Management
- Local state first — useState/ref for component-scoped state
- Global stores only for truly shared cross-component state
- Server state belongs in data-fetching layer:
  - Vue: useAsyncData / useFetch (Nuxt 4)
  - React: TanStack Query / Server Components
- Never duplicate server state in client stores
- Pinia setup stores (Vue) / Zustand (React) when global state needed

## Styling
- Scoped styles in Vue (`<style scoped>`)
- CSS Modules in React (`*.module.css`)
- Mobile-first with `min-width` breakpoints
- `prefers-reduced-motion` for all animations
- Design tokens via CSS custom properties
- No CSS-in-JS runtime libraries (styled-components, emotion)

## Forms
- Controlled inputs with validation
- Zod schemas for validation (shared between client and server)
- Show errors inline, near the relevant field
- Disable submit during pending state
- Vue: vee-validate or native composable
- React: useActionState + Server Actions (Next.js 16)

## Data Fetching
- Vue/Nuxt 4: useAsyncData with unique keys, shallowRef default
- React/Next.js 16: Server Components fetch, TanStack Query for client
- Always handle loading, error, and empty states
- AbortController for cancellable requests
- Optimistic updates for better perceived performance

## Error Boundaries
- Vue: onErrorCaptured + error.vue (Nuxt)
- React: ErrorBoundary components at route level + error.tsx (Next.js)
- User-friendly error messages, technical details in logs
- Recovery actions (retry, go back, refresh)
