// Odín's rules, without the mods API, so tests can drive them directly.
const HOUR = 3_600_000
const GRUMPY_MS = 3 * 60_000

const TESTS = /\b(just (check|ai-check|ai-tests)|pytest|unittest|vitest|jest|(npm|pnpm|yarn|bun) (run )?test|cargo test|go test|plugin test|playwright test)\b/
const COMMIT = /\bgit commit\b/

const clamp = (value) => Math.max(0, Math.min(100, Math.round(value)))

// Which reaction a finished shell command earns, or null.
export function kindOf(command, isError) {
  if (TESTS.test(command)) return isError ? 'test-fail' : 'test-pass'
  if (COMMIT.test(command) && !isError) return 'commit'
  return null
}

export function freshOdin(now) {
  return { hunger: 30, energy: 80, love: 50, updatedAt: now, event: 'Odín acaba de llegar a casa.', eventAt: now, grumpyUntil: 0 }
}

// Time passes: he gets hungry, rests and misses you a little.
export function decay(cat, now) {
  const hours = Math.max(0, (now - cat.updatedAt) / HOUR)
  return {
    ...cat,
    hunger: clamp(cat.hunger + hours * 8),
    energy: clamp(cat.energy + hours * 10),
    love: clamp(cat.love - hours * 2),
    updatedAt: now,
  }
}

const REACTIONS = {
  'test-pass': { hunger: -30, love: 5, event: 'Se ha zampado tus tests en verde. ¡Ñam!' },
  'test-fail': { love: -3, grumpy: true, event: 'Ha visto un test en rojo y te bufa: ¡fffff!' },
  commit: { love: 10, event: 'Te trae un ratón por el commit. Qué detalle.' },
  pet: { love: 8, event: 'Prrrrr… ronronea y te pone la cabeza en la mano.' },
  treat: { hunger: -15, event: 'Se come la chuche y ya pide otra.' },
  play: { energy: -15, love: 5, event: 'Persigue el puntero láser como un loco.' },
  aborted: { event: 'Se asusta y se esconde debajo del sofá.' },
}

export function react(cat, kind, now) {
  const reaction = REACTIONS[kind]
  if (!reaction) return cat
  return {
    ...cat,
    hunger: clamp(cat.hunger + (reaction.hunger ?? 0)),
    energy: clamp(cat.energy + (reaction.energy ?? 0)),
    love: clamp(cat.love + (reaction.love ?? 0)),
    grumpyUntil: reaction.grumpy ? now + GRUMPY_MS : cat.grumpyUntil,
    event: reaction.event,
    eventAt: now,
  }
}

export function mood(cat, now, hour) {
  if (now < cat.grumpyUntil) return 'enfadado'
  if (hour < 7 || cat.energy < 15) return 'durmiendo'
  if (cat.hunger >= 70) return 'hambriento'
  if (cat.love >= 70) return 'feliz'
  return 'tranquilo'
}

const FACES = { feliz: '^.^', tranquilo: 'o.o', hambriento: 'O.O', enfadado: 'ò.ó', durmiendo: '-.-' }
const SAYS = { feliz: 'mrrp ♥', tranquilo: '', hambriento: '¿y mi comida?', enfadado: 'fffff', durmiendo: 'zZz' }

export function art(state) {
  const says = SAYS[state] ? `  ${SAYS[state]}` : ''
  return [' /\\_/\\', `( ${FACES[state]} )${says}`, ' > ^ <']
}

export function face(state) {
  return `=${FACES[state]}=`
}

export function bar(value) {
  const full = Math.round(value / 10)
  return '█'.repeat(full) + '░'.repeat(10 - full)
}
