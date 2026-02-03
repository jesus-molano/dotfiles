---
name: a11y-audit
description: Audit project for WCAG 2.1 AA accessibility compliance
context: fork
agent: Explore
---

# Accessibility Audit (WCAG 2.1 AA)

Auto-detect framework and audit accordingly.

## Vue / Nuxt 4 Checks

- [ ] `<NuxtLink>` for navigation — never `<a @click>` or `<div @click>` for links
- [ ] `v-for` always has meaningful `:key` (not index for dynamic lists)
- [ ] `<Teleport>` modals have focus traps and restore focus on close
- [ ] `useId()` for connecting labels to inputs (Vue 3.5+)
- [ ] `<NuxtImage>` / `<NuxtPicture>` always has `alt` attribute
- [ ] Route announcements for SPA navigation

## React / Next.js 16 Checks

- [ ] `next/image` always has descriptive `alt` (empty string for decorative)
- [ ] `<Fragment>` usage doesn't break heading hierarchy
- [ ] Portaled modals have focus traps and `aria-modal="true"`
- [ ] `useId()` for connecting labels to inputs (React 19)
- [ ] `next/link` for navigation — never `<div onClick>` for links
- [ ] Error boundaries have accessible error messages

## Perceivable (WCAG 1.x)

- [ ] All images have alt text (descriptive or empty for decorative)
- [ ] Color contrast ratio ≥ 4.5:1 (text) / 3:1 (large text, UI components)
- [ ] Information not conveyed by color alone
- [ ] Video/audio has captions or transcripts
- [ ] Text resizable to 200% without loss of content
- [ ] Content reflows at 320px viewport width

## Operable (WCAG 2.x)

- [ ] All interactive elements keyboard accessible (Tab, Enter, Space, Escape)
- [ ] Visible focus indicators on all focusable elements
- [ ] Skip navigation link present
- [ ] No keyboard traps (except intentional modals with Escape)
- [ ] Touch targets ≥ 44x44px
- [ ] No time limits without user control
- [ ] `prefers-reduced-motion` respected for animations

## Understandable (WCAG 3.x)

- [ ] `lang` attribute on `<html>`
- [ ] Form inputs have visible labels (not placeholder-only)
- [ ] Error messages are specific and suggest corrections
- [ ] Consistent navigation patterns across pages
- [ ] Abbreviations and jargon explained on first use

## Robust (WCAG 4.x)

- [ ] Valid semantic HTML (proper heading hierarchy h1→h2→h3)
- [ ] ARIA roles used correctly (no redundant roles on semantic elements)
- [ ] `aria-live` regions for dynamic content updates
- [ ] Form validation errors announced to screen readers
- [ ] Custom components expose correct ARIA roles and states

## Output Format

Group findings by WCAG principle:

### Critical (A violations)
Must fix — blocks users from accessing content.
Format: `file:line — WCAG criterion — issue — fix`

### Major (AA violations)
Should fix — significantly degrades experience.
Format: `file:line — WCAG criterion — issue — fix`

### Minor (Best practices)
Improvements for better UX.
Format: `file:line — issue — recommendation`
