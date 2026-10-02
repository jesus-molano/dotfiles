// Noctalia's active palette as plain data. appearance-switch renders the file
// on every theme change (noctalia config.toml, theme.templates.user.active_palette)
// and records the appearance id; register.js reads them.
export const PALETTE = '/.config/noctalia/generated/active-palette.json'
export const CURRENT = '/.local/state/dotfiles/appearance-switch/current'
export const CATALOG = '/.config/noctalia/appearances/catalog.tsv'

// Theme keys, so the mods still draw when Noctalia is missing.
export const FALLBACK = {
  primary: 'magenta', secondary: 'cyan', tertiary: 'yellow', error: 'red', muted: 'gray', name: '',
}

const RIBBON = ['primary', 'secondary', 'tertiary', 'error']
export const SWATCHES = ['primary', 'secondary', 'tertiary', 'error', 'muted']

export function parsePalette(text) {
  const data = JSON.parse(text)
  const scheme = data.dark ?? data.light ?? data
  const colors = {
    primary: scheme.mPrimary, secondary: scheme.mSecondary, tertiary: scheme.mTertiary,
    error: scheme.mError, muted: scheme.mOnSurfaceVariant,
  }
  for (const [key, value] of Object.entries(colors)) {
    if (!/^#[0-9a-fA-F]{6}$/.test(value ?? '')) colors[key] = FALLBACK[key]
  }
  return colors
}

// catalog.tsv: id, label, palette source, palette name, wallpaper hint.
export function appearanceLabel(id, catalog) {
  for (const line of catalog.split('\n')) {
    if (line.startsWith('#')) continue
    const [key, label] = line.split('\t')
    if (key === id && label) return label
  }
  return id
}

// The ribbon above the prompt: one run of ━ per color, then the theme's name.
export function ribbonParts(colors, columns) {
  const label = colors.name ? ` ${colors.name} ` : ''
  const width = Math.max(RIBBON.length, columns - label.length)
  const size = Math.floor(width / RIBBON.length)
  const parts = RIBBON.map((key) => ({ color: colors[key], text: '━'.repeat(size), bold: false }))
  if (label) parts.push({ color: colors.primary, text: label, bold: true })
  return parts
}
