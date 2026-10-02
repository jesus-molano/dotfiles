// /parte without the mods API: the period, ticket keys, the facts for the
// model and a plain fallback when the model does not answer.
const DAY = 86_400_000
const TICKET = /\b([A-Za-z]{2,10}-\d{1,6})\b/g

export const SYSTEM = [
  'Escribe un parte diario para pegar en Slack, en español de España, en primera persona y con tono cercano y breve.',
  'Formato mrkdwn de Slack: tres bloques con el título en negrita (*Título*) y viñetas con «•».',
  'Bloques: el periodo que te indiquen, *Hoy* y *Bloqueos*.',
  'Usa solo los hechos que te doy; no inventes trabajo, tickets ni enlaces.',
  'Agrupa los commits del mismo ticket en una viñeta que empiece por la clave en mayúsculas.',
  'En *Hoy* propone seguir con las ramas abiertas y las PR pendientes. En *Bloqueos* escribe «Ninguno» si no hay datos.',
  'Como mucho 8 viñetas en total. Responde solo con el parte.',
].join('\n')

function midnight(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

// No argument: since yesterday, or since Friday on a weekend or a Monday.
export function period(now, args) {
  const today = midnight(now)
  const days = Number.parseInt(String(args ?? '').trim(), 10)
  if (Number.isInteger(days) && days > 0) {
    return { since: new Date(today.getTime() - days * DAY), label: days === 1 ? 'Ayer' : `Últimos ${days} días` }
  }
  const back = { 0: 2, 1: 3, 6: 1 }[today.getDay()] ?? 1
  return { since: new Date(today.getTime() - back * DAY), label: back === 1 ? 'Ayer' : 'Desde el viernes' }
}

export function isoDay(date) {
  const pad = (n) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

export function tickets(text) {
  return [...new Set([...text.matchAll(TICKET)].map((m) => m[1].toUpperCase()))]
}

// repos: [{ name, commits: [subject], branches: [name] }]; prs: [{ title, url, state, repo }]
export function factsText(label, repos, prs) {
  const lines = [`Periodo: *${label}*`]
  for (const repo of repos) {
    lines.push(`Repositorio ${repo.name}:`)
    for (const subject of repo.commits) lines.push(`- commit: ${subject}`)
    for (const branch of repo.branches) lines.push(`- rama abierta: ${branch}`)
  }
  for (const pr of prs) lines.push(`- PR ${pr.state} en ${pr.repo}: ${pr.title} (${pr.url})`)
  const keys = tickets(lines.join('\n'))
  if (keys.length) lines.push(`Tickets: ${keys.join(', ')}`)
  return lines.join('\n')
}

export function fallbackParte(label, repos, prs) {
  const done = repos.flatMap((repo) => repo.commits.map((subject) => `• ${subject} (${repo.name})`))
  const next = [
    ...repos.flatMap((repo) => repo.branches.map((branch) => `• Seguir con ${branch} (${repo.name})`)),
    ...prs.filter((pr) => pr.state === 'open').map((pr) => `• Mover la PR «${pr.title}»`),
  ]
  return [
    `*${label}*`, ...(done.length ? done : ['• Nada en Git']),
    '*Hoy*', ...(next.length ? next : ['• Por decidir']),
    '*Bloqueos*', '• Ninguno',
  ].join('\n')
}
