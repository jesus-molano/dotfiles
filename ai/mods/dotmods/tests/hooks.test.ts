import { expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'dotmods',
  component: 'Pane',
  requestId: 'odin',
  viewport: { columns: 120, rows: 40 },
  props: { title: 'Odín', isFocused: true, bodyColumns: 50, placement: 'inline', scroll: { offset: 0, bodyRows: 20 }, view: {} },
} as const

const BAND = {
  plugin: 'dotmods',
  component: 'AbovePrompt',
  requestId: 'band',
  viewport: { columns: 120, rows: 40 },
  props: { hasSurvey: false, isWorking: false, maxRows: 5, bodyColumns: 60, scroll: { offset: 0, bodyRows: 5 }, view: {} },
} as const

const PALETTE = JSON.stringify({ dark: { mPrimary: '#c4a7e7', mSecondary: '#9ccfd8', mTertiary: '#ebbcba', mError: '#eb6f92', mOnSurfaceVariant: '#908caa' } })

// Stubs for the calls every session start makes.
function home(on, saved: Map<string, unknown>) {
  on('env.get', () => ({ value: '/home/test' }))
  on('fs.stat', () => ({ value: { kind: 'file', size: 1, mtimeMs: 1, isLink: false } }))
  on('fs.read', ($, e) => ({
    value: e.path.endsWith('active-palette.json') ? PALETTE
      : e.path.endsWith('current') ? 'rose-pine\n'
        : 'rose-pine\tRosé Pine Moon\tcustom\tRosePine\t-\n',
  }))
  on('store.get', ($, e) => ({ value: saved.get(e.key) }))
  on('store.set', ($, e) => {
    saved.set(e.key, e.value)
    return { value: undefined }
  })
  on('command.register', () => ({ value: undefined }))
  on('session.start', () => ({ cwd: '/work' }))
}

test('the band shows the Noctalia ribbon with the theme name', async ($, on) => {
  mock.clock(on, { now: Date.UTC(2026, 9, 2, 12) })
  home(on, new Map())
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['other mods'] }))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: ' Rosé Pine Moon ' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'other mods' })).toBeDefined()
})

test('a green test feeds Odín and a press pets him', async ($, on) => {
  const saved = new Map<string, unknown>()
  mock.clock(on, { now: Date.UTC(2026, 9, 2, 12) })
  home(on, saved)
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['engine'] }))
  on('tool.call', () => ({ result: { stdout: 'ok', stderr: '' } }))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })

  await $.tool.call({ tool: 'Bash', command: 'just check' })
  expect((saved.get('odin') as { event: string }).event).toContain('tests en verde')

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'pet' })
  expect((saved.get('odin') as { event: string }).event).toContain('ronronea')
  expect(await ui.find({ key: 'treat' })).toBeDefined()
})

test('a red test makes Odín hiss; denied and background calls do not count', async ($, on) => {
  const saved = new Map<string, unknown>()
  mock.clock(on, { now: Date.UTC(2026, 9, 2, 12) })
  home(on, saved)
  on('tool.call', ($, e) => e.command === 'just check' ? { deny: 'no' }
    : e.command === 'pytest' ? { result: { stdout: '', stderr: '', backgroundTaskId: 'b1' } }
      : { result: { stdout: '', stderr: 'boom' }, isError: true })
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })

  await $.tool.call({ tool: 'Bash', command: 'just check' })
  await $.tool.call({ tool: 'Bash', command: 'pytest' })
  expect(saved.get('odin')).toBeUndefined()
  await $.tool.call({ tool: 'Bash', command: 'npm test' })
  expect((saved.get('odin') as { event: string }).event).toContain('bufa')
})

// Stubs for /parte: one repository with one commit, gh offline.
function parteWorld(on, gitCalls: string[][]) {
  on('fs.list', () => ({ value: [] }))
  on('fs.exists', ($, e) => ({ value: e.path === '/home/test/.dotfiles/.git' }))
  on('session.root', () => ({ value: '/home/test/.dotfiles' }))
  on('process.run', ($, e) => {
    const [program, ...args] = e.argv
    if (program === 'gh') return { value: { exitCode: 1, stdout: '', stderr: 'offline' } }
    gitCalls.push(args)
    if (args[0] === 'config') return { value: { exitCode: 0, stdout: 'me@example.test\n', stderr: '' } }
    if (args[0] === 'log') return { value: { exitCode: 0, stdout: 'HH-707 Keep the phone field\n', stderr: '' } }
    return { value: { exitCode: 0, stdout: '', stderr: '' } }
  })
  on('ui.toast', () => ({ value: undefined }))
}

test('/parte writes the stand-up from Git since midnight and copies it', async ($, on) => {
  mock.clock(on, { now: new Date(2026, 9, 7, 10).getTime() })
  home(on, new Map())
  const gitCalls: string[][] = []
  parteWorld(on, gitCalls)
  const copied: string[] = []
  on('session.surfaces', () => ({ value: ['terminal'] }))
  on('ui.copy', ($, e) => {
    copied.push(e.text)
    return { value: { isCopied: true } }
  })
  on('model.complete', () => ({
    value: { isAnswered: true, text: '*Ayer*\n• HH-707 Campo de teléfono\n*Hoy*\n• Seguir\n*Bloqueos*\n• Ninguno', usage: { input_tokens: 1, output_tokens: 1, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } },
  }))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })

  const answer = await $.command.run({ command: 'parte', args: '' })
  expect(answer.text).toContain('HH-707')
  expect(answer.text).toContain('copiado al portapapeles')
  expect(copied[0]).toContain('*Bloqueos*')
  expect(gitCalls.find((args) => args[0] === 'log')).toContain('--since=2026-10-06 00:00:00')
})

test('/parte falls back to a plain stand-up when the model call is refused', async ($, on) => {
  mock.clock(on, { now: new Date(2026, 9, 7, 10).getTime() })
  home(on, new Map())
  parteWorld(on, [])
  on('session.surfaces', () => ({ value: [] }))
  on('model.complete', () => ({ deny: 'model blocked' }))
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })

  const answer = await $.command.run({ command: 'parte', args: '' })
  expect(answer.text).toContain('• HH-707 Keep the phone field (.dotfiles)')
  expect(answer.text).not.toContain('copiado')
})
