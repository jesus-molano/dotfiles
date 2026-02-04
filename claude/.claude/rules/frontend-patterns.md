---
description: Framework-specific patterns for Vue/Nuxt and React/Next.js
paths:
  - "**/*.vue"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/components/**"
  - "**/composables/**"
  - "**/hooks/**"
---

# Frontend Patterns

## State Management
- Local state first (ref/useState). Global stores only for shared cross-component state
- Server state in data-fetching layer, never in client stores
- Vue: Pinia setup stores. React: Zustand
- Vue: useAsyncData/useFetch with unique keys. React: TanStack Query / Server Components

## Styling
- Vue: `<style scoped>`. React: CSS Modules. No CSS-in-JS runtime
- Mobile-first (`min-width`). `prefers-reduced-motion` for animations

## Data Fetching
- Vue/Nuxt 4: useAsyncData with shallowRef default
- React/Next.js 16: Server Components default, TanStack Query for client
- Always handle loading, error, empty states
