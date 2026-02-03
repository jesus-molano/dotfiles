---
name: scaffold-component
description: Scaffold a Vue or React component with optional tests and stories
disable-model-invocation: true
arguments:
  - name: name
    description: Component name in PascalCase (e.g., UserProfile)
    required: true
  - name: with-tests
    description: Generate co-located test file
    type: boolean
  - name: with-story
    description: Generate co-located Storybook story
    type: boolean
---

# Scaffold Component

Auto-detect framework from project config:
- `nuxt.config.ts` or `nuxt.config.js` → Vue/Nuxt 4
- `next.config.ts` or `next.config.js` → React/Next.js 16

## Vue (Nuxt 4)

Create `{name}.vue`:
```vue
<script setup lang="ts">
interface Props {
  // Define props
}

const props = defineProps<Props>()
const emit = defineEmits<{
  // Define events
}>()

onUnmounted(() => {
  // Cleanup: event listeners, intervals, subscriptions
})
</script>

<template>
  <div>
    <!-- Component template -->
  </div>
</template>

<style scoped>
/* Scoped styles */
</style>
```

If `--with-tests`, create `{name}.test.ts`:
```ts
import { mountSuspended } from '@nuxt/test-utils/runtime'
import { describe, expect, it } from 'vitest'
import {name} from './{name}.vue'

describe('{name}', () => {
  it('renders correctly', async () => {
    const wrapper = await mountSuspended({name})
    expect(wrapper.exists()).toBe(true)
  })
})
```

If `--with-story`, create `{name}.stories.ts`:
```ts
import type { Meta, StoryObj } from '@storybook/vue3'
import {name} from './{name}.vue'

const meta = {
  title: 'Components/{name}',
  component: {name},
} satisfies Meta<typeof {name}>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
```

## React (Next.js 16)

Create `{name}.tsx`:
```tsx
interface {name}Props {
  // Define props
}

export function {name}({ }: {name}Props) {
  useEffect(() => {
    return () => {
      // Cleanup: event listeners, intervals, subscriptions
    }
  }, [])

  return (
    <div>
      {/* Component JSX */}
    </div>
  )
}
```

If `--with-tests`, create `{name}.test.tsx`:
```tsx
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { {name} } from './{name}'

describe('{name}', () => {
  it('renders correctly', () => {
    render(<{name} />)
    expect(screen.getByRole('...')).toBeInTheDocument()
  })
})
```

If `--with-story`, create `{name}.stories.tsx`:
```tsx
import type { Meta, StoryObj } from '@storybook/react'
import { {name} } from './{name}'

const meta = {
  title: 'Components/{name}',
  component: {name},
} satisfies Meta<typeof {name}>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
```

## Rules
- Place the component in the nearest `components/` directory or current directory
- Use PascalCase for file names
- Always include TypeScript types for props
- Always include cleanup in onUnmounted (Vue) or useEffect return (React)
- Never add "use client" unless the component uses client-only APIs (hooks, event handlers, browser APIs)
