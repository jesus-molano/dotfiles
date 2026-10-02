// dotmods: three house mods in one plugin.
//   · Noctalia: a ribbon in the active palette above the prompt, a toast on
//     theme change and /noctalia.
//   · Odín, el gatito del repo: eats green tests, hisses at red ones, brings a
//     mouse for each commit and lives in a pane opened with /odin.
//   · /parte [días]: the daily stand-up for Slack, copied as /copy does.
// `claude plugin validate` follows $ only inside this file, so every call on
// the mods API lives here; the rules are plain functions in sibling modules.
import { appearanceLabel, CATALOG, CURRENT, FALLBACK, PALETTE, parsePalette, ribbonParts, SWATCHES } from './palette.js'
import { art, bar, decay, face, freshOdin, kindOf, mood, react } from './odin-mood.js'
import { factsText, fallbackParte, isoDay, period, SYSTEM } from './parte-facts.js'

const PALETTE_POLL_MS = 5000
const ODIN_KEY = 'odin'
const ODIN_PANE = 'odin'
// Odín's latest reaction stays in the band above the prompt for this long.
const ODIN_BAND_MS = 2 * 60_000
// Folders under $HOME whose direct children are repositories, plus the dotfiles.
const PARTE_ROOTS = ['dev', 'Projects']
const MAIN_BRANCHES = new Set(['main', 'master', 'develop'])

let theme = { mtime: -1, colors: FALLBACK }
let cat = null

// ── Noctalia ────────────────────────────────────────────────────────────────

async function readText($, path) {
  try {
    return await $.fs.read(path)
  } catch {
    return ''
  }
}

// Rereads the palette when its file changed. Resolves true on a change.
async function refreshPalette($) {
  const home = await $.env.get('HOME')
  let stat
  try {
    stat = await $.fs.stat(home + PALETTE)
  } catch {
    return false
  }
  if (stat.mtimeMs === theme.mtime) return false
  let colors = FALLBACK
  try {
    colors = parsePalette(await $.fs.read(home + PALETTE))
  } catch {
    // A half-written file: keep the fallback until the next change.
  }
  const id = (await readText($, home + CURRENT)).trim()
  const name = id ? appearanceLabel(id, await readText($, home + CATALOG)) : ''
  theme = { mtime: stat.mtimeMs, colors: { ...colors, name } }
  return true
}

async function startNoctalia($) {
  await refreshPalette($)
  $.clock.every(PALETTE_POLL_MS, async () => {
    if (!(await refreshPalette($))) return
    $.ui.invalidate('ui.render')
    $.ui.toast('🎨 Claude se viste de ' + (theme.colors.name || 'Noctalia'))
  })
  await $.command.register({ name: 'noctalia', description: 'Muestra la paleta de Noctalia que usa Claude Code' })
}

function noctaliaRibbon($, e) {
  const { Box, Text } = $.ui.resolve(e)
  return Box({
    flexDirection: 'row',
    children: ribbonParts(theme.colors, e.props.bodyColumns ?? 80)
      .map((part) => Text({ color: part.color, bold: part.bold, children: [part.text] })),
  })
}

// ── Odín ────────────────────────────────────────────────────────────────────

async function loadOdin($) {
  const now = await $.clock.now()
  const saved = await $.store.get(ODIN_KEY)
  return decay(saved ?? freshOdin(now), now)
}

async function feel($, kind) {
  const now = await $.clock.now()
  cat = react(await loadOdin($), kind, now)
  await $.store.set(ODIN_KEY, cat)
  $.ui.invalidate('ui.render')
  // Claude Code redraws only on change, so ask again once the band line expires.
  $.clock.after(ODIN_BAND_MS + 1000, () => $.ui.invalidate('ui.render'))
}

function hourOf(now) {
  return new Date(now).getHours()
}

async function startOdin($) {
  cat = await loadOdin($)
  await $.command.register({ name: 'odin', description: 'Abre el panel de Odín, el gatito del repo', immediate: true })
}

async function odinLine($, e) {
  const now = await $.clock.now()
  if (!cat || now - cat.eventAt > ODIN_BAND_MS) return null
  const { Text } = $.ui.resolve(e)
  return Text({
    color: theme.colors.primary,
    wrap: 'truncate-end',
    children: [`${face(mood(cat, now, hourOf(now)))} Odín: ${cat.event}`],
  })
}

// ── /parte ──────────────────────────────────────────────────────────────────

async function git($, cwd, args) {
  try {
    const run = await $.process.run(['git', ...args], { cwd, timeoutMs: 15_000 })
    return run.exitCode === 0 ? run.stdout.trim() : ''
  } catch {
    return ''
  }
}

async function repositories($, home) {
  const found = [home + '/.dotfiles']
  for (const root of PARTE_ROOTS) {
    let entries = []
    try {
      entries = await $.fs.list(`${home}/${root}`)
    } catch {
      continue
    }
    // A linked repository lists as 'other'; the .git check below filters it.
    for (const entry of entries) {
      if (entry.kind !== 'file') found.push(`${home}/${root}/${entry.name}`)
    }
  }
  try {
    found.push(await $.session.root())
  } catch {
    // No session root: the folders above are enough.
  }
  const repos = []
  for (const path of new Set(found)) {
    if (await $.fs.exists(path + '/.git')) repos.push(path)
  }
  return repos
}

async function activity($, path, since) {
  const email = await git($, path, ['config', 'user.email'])
  if (!email) return null
  const day = isoDay(since)
  // A bare date takes the current time of day; midnight covers the whole day.
  const log = await git($, path, ['log', '--all', '--no-merges', `--since=${day} 00:00:00`, `--author=${email}`, '--format=%s'])
  const refs = await git($, path, ['for-each-ref', '--sort=-committerdate', '--format=%(refname:short)\t%(committerdate:short)', 'refs/heads'])
  const branches = refs.split('\n')
    .map((line) => line.split('\t'))
    .filter(([name, date]) => name && date >= day && !MAIN_BRANCHES.has(name))
    .map(([name]) => name)
  const commits = log ? [...new Set(log.split('\n'))] : []
  if (!commits.length && !branches.length) return null
  return { name: path.split('/').pop(), commits, branches }
}

async function pullRequests($, since) {
  try {
    const run = await $.process.run(['gh', 'search', 'prs', '--author=@me', `--updated=>=${isoDay(since)}`,
      '--json', 'title,url,state,repository', '--limit', '30'], { timeoutMs: 20_000 })
    if (run.exitCode !== 0) return []
    return JSON.parse(run.stdout)
      .map((pr) => ({ title: pr.title, url: pr.url, state: pr.state, repo: pr.repository?.nameWithOwner ?? '' }))
  } catch {
    return []
  }
}

// Copies as /copy does; `claude -p` has no surface and copies nothing.
async function copyText($, text) {
  try {
    const surfaces = await $.session.surfaces()
    const surface = surfaces.includes('terminal') ? 'terminal' : surfaces[0]
    if (!surface) return false
    const copied = await $.ui.copy({ text, surface })
    return copied?.isCopied === true
  } catch {
    return false
  }
}

async function writeParte($, label, repos, prs) {
  try {
    const reply = await $.model.complete({ model: 'haiku', system: SYSTEM, prompt: factsText(label, repos, prs), maxTokens: 700 })
    if (reply.isAnswered && reply.text.trim()) return reply.text.trim()
  } catch {
    // A refused model call falls back like an unanswered one.
  }
  return fallbackParte(label, repos, prs)
}

async function startParte($) {
  await $.command.register({ name: 'parte', description: 'Escribe tu parte diario para Slack y lo copia', argumentHint: '[días]' })
}

// ── Hooks ───────────────────────────────────────────────────────────────────

export function register(on) {
  on('session.start', async ($, e, next) => {
    // A failing feature must not keep the others from starting; its hooks
    // fall back to their defaults.
    await startNoctalia($).catch(() => {})
    await startOdin($).catch(() => {})
    await startParte($).catch(() => {})
    return next(e)
  })

  // Noctalia's ribbon on top, then Odín's latest reaction, then other mods.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const below = await next(e)
    const { Box } = $.ui.resolve(e)
    const rows = [noctaliaRibbon($, e), await odinLine($, e), below].filter(Boolean)
    return Box({ flexDirection: 'column', children: rows })
  })

  on('command.run', { command: 'noctalia' }, async ($) => {
    await refreshPalette($)
    const colors = theme.colors
    return {
      text: [
        `Paleta activa: ${colors.name || 'sin nombre (¿Noctalia apagado?)'}`,
        ...SWATCHES.map((key) => `• ${key}: ${colors[key]}`),
        '',
        'La cinta sobre el prompt sigue esta paleta. Para que el resto de Claude Code',
        'también la siga, elige en /config el tema «Dark mode (ANSI colors only)»:',
        'usa los colores de tu terminal, que Noctalia ya genera.',
      ].join('\n'),
    }
  })

  on('command.run', { command: 'odin' }, async ($) => {
    // Focus, so the a, c and j hotkeys reach his buttons and not the prompt.
    await $.ui.open({ id: ODIN_PANE, title: 'Odín', focus: true, closeOnEscape: true })
    return {}
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const result = await next(e)
    // A denied call never ran, and a background one has not finished yet.
    const finished = !result.deny && !result.result?.backgroundTaskId
    const kind = finished && typeof e.command === 'string' ? kindOf(e.command, result.isError === true) : null
    // A missed reaction never touches the tool's result.
    if (kind) await feel($, kind).catch(() => {})
    return result
  })

  on('turn.complete', async ($, e, next) => {
    if (e.isAborted && !e.agentId) await feel($, 'aborted').catch(() => {})
    return next(e)
  })

  on('ui.render', { component: 'Pane' }, async ($, e, next) => {
    if (e.requestId !== ODIN_PANE) return next(e)
    const { Box, Text, Button } = $.ui.resolve(e)
    const now = await $.clock.now()
    const current = decay(cat ?? freshOdin(now), now)
    const state = mood(current, now, hourOf(now))
    const colors = theme.colors
    const stat = (label, value, color) => Box({
      flexDirection: 'row',
      columnGap: 1,
      children: [Text({ children: [label.padEnd(7)] }), Text({ color, children: [bar(value)] })],
    })
    return Box({
      flexDirection: 'column',
      gap: 1,
      children: [
        Box({
          flexDirection: 'column',
          children: art(state).map((line) => Text({ color: colors.primary, bold: true, children: [line] })),
        }),
        Text({ children: [Text({ bold: true, children: ['Odín'] }), ` · ${state}`] }),
        Box({
          flexDirection: 'column',
          children: [
            stat('Hambre', current.hunger, colors.error),
            stat('Energía', current.energy, colors.secondary),
            stat('Cariño', current.love, colors.tertiary),
          ],
        }),
        Text({ italic: true, color: colors.muted, children: [current.event] }),
        Box({
          flexDirection: 'row',
          columnGap: 2,
          children: [
            Button({ key: 'pet', label: 'Acariciar', hotkey: 'a', onPress: () => feel($, 'pet') }),
            Button({ key: 'treat', label: 'Chuche', hotkey: 'c', onPress: () => feel($, 'treat') }),
            Button({ key: 'play', label: 'Jugar', hotkey: 'j', onPress: () => feel($, 'play') }),
          ],
        }),
      ],
    })
  })

  on('command.run', { command: 'parte' }, async ($, e) => {
    const home = await $.env.get('HOME')
    const { since, label } = period(new Date(await $.clock.now()), e.args)
    const repos = []
    for (const path of await repositories($, home)) {
      const found = await activity($, path, since)
      if (found) repos.push(found)
    }
    const prs = await pullRequests($, since)
    if (!repos.length && !prs.length) {
      return { text: `No he encontrado commits, ramas ni PR tuyas desde el ${isoDay(since)}. ¿Día de reuniones?` }
    }
    const parte = await writeParte($, label, repos, prs)
    const copied = await copyText($, parte)
    if (copied) $.ui.toast('📋 Parte copiado. Pégalo en Slack.')
    return { text: copied ? `${parte}\n\n(copiado al portapapeles)` : parte }
  })
}
