import { expect, test } from 'claude-code/testing'
import { appearanceLabel, FALLBACK, parsePalette, ribbonParts } from '../hooks/palette.js'
import { bar, decay, freshOdin, kindOf, mood, react } from '../hooks/odin-mood.js'
import { fallbackParte, factsText, isoDay, period, tickets } from '../hooks/parte-facts.js'

const HOUR = 3_600_000

test('the palette reads the dark scheme and falls back on bad colors', async () => {
  const colors = parsePalette(JSON.stringify({ dark: { mPrimary: '#c4a7e7', mSecondary: 'nope', mTertiary: '#ebbcba', mError: '#eb6f92', mOnSurfaceVariant: '#908caa' } }))
  expect(colors.primary).toBe('#c4a7e7')
  expect(colors.secondary).toBe(FALLBACK.secondary)
})

test('the appearance label comes from the catalog', async () => {
  const catalog = '# id\tlabel\nrose-pine\tRosé Pine Moon\tcustom\tRosePine\t-\n'
  expect(appearanceLabel('rose-pine', catalog)).toBe('Rosé Pine Moon')
  expect(appearanceLabel('missing', catalog)).toBe('missing')
})

test('the ribbon fills the width and ends with the theme name', async () => {
  const parts = ribbonParts({ ...FALLBACK, name: 'Atlas' }, 47)
  expect(parts.length).toBe(5)
  expect(parts[4].text).toBe(' Atlas ')
  expect(parts[0].text).toBe('━'.repeat(10))
})

test('Odín eats green tests, hisses at red ones and loves commits', async () => {
  expect(kindOf('just check', false)).toBe('test-pass')
  expect(kindOf('python3 -m unittest discover', true)).toBe('test-fail')
  expect(kindOf('git commit -F .git/COMMIT_DRAFT', false)).toBe('commit')
  expect(kindOf('git commit -F .git/COMMIT_DRAFT', true)).toBe(null)
  expect(kindOf('ls -la', false)).toBe(null)
})

test('Odín gets hungry over time and grumpy after a red test', async () => {
  const start = freshOdin(0)
  const later = decay(start, 6 * HOUR)
  expect(later.hunger).toBe(78)
  expect(mood(later, 6 * HOUR, 12)).toBe('hambriento')
  const fed = react(later, 'test-pass', 6 * HOUR)
  expect(fed.hunger).toBe(48)
  const grumpy = react(fed, 'test-fail', 6 * HOUR)
  expect(mood(grumpy, 6 * HOUR + 1000, 12)).toBe('enfadado')
  expect(mood(grumpy, 7 * HOUR, 3)).toBe('durmiendo')
  expect(bar(48)).toBe('█████░░░░░')
})

test('the parte period covers yesterday, or the weekend on a Monday', async () => {
  const wednesday = period(new Date(2026, 9, 7, 10), '')
  expect(isoDay(wednesday.since)).toBe('2026-10-06')
  expect(wednesday.label).toBe('Ayer')
  const monday = period(new Date(2026, 9, 5, 10), '')
  expect(isoDay(monday.since)).toBe('2026-10-02')
  expect(monday.label).toBe('Desde el viernes')
  expect(period(new Date(2026, 9, 7, 10), '3').label).toBe('Últimos 3 días')
})

test('the parte facts name tickets and the fallback has three blocks', async () => {
  expect(tickets('feat/hh-707-phone y HH-707 otra vez, fix HH-12')).toEqual(['HH-707', 'HH-12'])
  const repos = [{ name: 'web', commits: ['HH-707 Keep the phone field'], branches: ['feat/hh-707-phone'] }]
  const prs = [{ title: 'HH-707 Keep the phone field', url: 'https://example.test/1', state: 'open', repo: 'acme/web' }]
  expect(factsText('Ayer', repos, prs)).toContain('Tickets: HH-707')
  const text = fallbackParte('Ayer', repos, prs)
  expect(text).toContain('*Ayer*')
  expect(text).toContain('*Hoy*')
  expect(text).toContain('*Bloqueos*')
})
