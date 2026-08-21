"""Qutebrowser keyboard-first con la paleta activa de Noctalia."""

import json
from pathlib import Path


DEFAULT_PALETTE = {
    "background": "#090a0d",
    "surface": "#14171c",
    "surface_variant": "#1b1f26",
    "hover": "#222731",
    "outline": "#454b57",
    "foreground": "#f1f3f5",
    "muted": "#a8afba",
    "primary": "#ff5b4d",
    "on_primary": "#180a08",
    "secondary": "#83a7c4",
    "tertiary": "#c4a663",
    "error": "#d86f91",
    "green": "#73bd8a",
}


def _is_hex_color(value):
    return (
        isinstance(value, str)
        and len(value) == 7
        and value.startswith("#")
        and all(character in "0123456789abcdefABCDEF" for character in value[1:])
    )


def _read_palette(path):
    """Read only the color fields qutebrowser needs from a palette JSON file."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return {}

    dark = data.get("dark") if isinstance(data, dict) else None
    terminal = dark.get("terminal") if isinstance(dark, dict) else None
    normal = terminal.get("normal") if isinstance(terminal, dict) else None
    if not isinstance(dark, dict):
        return {}

    fields = {
        "background": terminal.get("background") if isinstance(terminal, dict) else None,
        "surface": dark.get("mSurface"),
        "surface_variant": dark.get("mSurfaceVariant"),
        "hover": dark.get("mHover"),
        "outline": dark.get("mOutline"),
        "foreground": terminal.get("foreground") if isinstance(terminal, dict) else None,
        "muted": dark.get("mOnSurfaceVariant"),
        "primary": dark.get("mPrimary"),
        "on_primary": dark.get("mOnPrimary"),
        "secondary": dark.get("mSecondary"),
        "tertiary": dark.get("mTertiary"),
        "error": dark.get("mError"),
        "green": normal.get("green") if isinstance(normal, dict) else None,
    }
    return {name: value for name, value in fields.items() if _is_hex_color(value)}


def _load_palette(active_path=None, fallback_path=None):
    """Prefer Noctalia's generated palette and safely fall back to Project Atlas."""
    config_dir = Path.home() / ".config/noctalia"
    active_path = active_path or config_dir / "generated/active-palette.json"
    fallback_path = fallback_path or config_dir / "palettes/ProjectAtlas.json"

    palette = DEFAULT_PALETTE.copy()
    palette.update(_read_palette(fallback_path))
    palette.update(_read_palette(active_path))
    return palette

# Keep per-site permissions and temporary changes made with :set, while this
# file remains the canonical source for the shared profile defaults.
config.load_autoconfig()


# Blocking: Brave's ABP engine handles cosmetic/network rules and the hosts
# backend provides a small second layer. Fanboy Annoyances already includes
# the EasyList Cookie and Social lists, so those must not be added separately.
c.content.blocking.enabled = True
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://easylist-downloads.adblockplus.org/easylistspanish.txt",
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
]
c.content.blocking.hosts.lists = [
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
]
c.content.blocking.hosts.block_subdomains = True


# Vim-like behaviour and a compact, predictable interface.
c.auto_save.session = True
c.session.lazy_restore = True
c.confirm_quit = ["downloads"]
c.scrolling.smooth = False
c.tabs.background = True
c.tabs.last_close = "close"
c.tabs.new_position.related = "next"
c.tabs.new_position.unrelated = "last"
c.tabs.position = "top"
c.tabs.select_on_remove = "last-used"
c.tabs.show = "multiple"
c.tabs.title.format = "{audio}{index}: {current_title}"
c.tabs.title.format_pinned = "{index}: {current_title}"
c.tabs.indicator.width = 0
c.statusbar.position = "bottom"
c.statusbar.show = "always"
c.completion.height = "35%"
c.completion.shrink = True
c.hints.chars = "asdfghjkl"
c.hints.uppercase = False
c.keyhint.delay = 0
c.input.insert_mode.auto_leave = True
c.input.insert_mode.auto_load = False


# Use Neovim for textareas with Ctrl-E from insert mode.
c.editor.command = [
    "ghostty",
    "-e",
    "nvim",
    "{file}",
    "+call cursor({line}, {column})",
]


# Search prefixes are intentionally short enough to use from normal mode with
# `o` or `O`, for example: `O gh qutebrowser`.
c.url.default_page = "https://www.google.com/"
c.url.start_pages = ["https://www.google.com/"]
c.url.searchengines = {
    "DEFAULT": "https://www.google.com/search?q={}",
    "aw": "https://wiki.archlinux.org/index.php?search={}",
    "archpkg": "https://archlinux.org/packages/?q={}",
    "aur": "https://aur.archlinux.org/packages?O=0&K={}",
    "g": "https://www.google.com/search?q={}",
    "gh": "https://github.com/search?q={}",
    "ghc": "https://github.com/search?q={}&type=code",
    "mdn": "https://developer.mozilla.org/en-US/search?q={}",
    "npm": "https://www.npmjs.com/search?q={}",
    "pypi": "https://pypi.org/search/?q={}",
    "qute": "https://www.google.com/search?q=site%3Aqutebrowser.org%2Fdoc+{}",
    "so": "https://stackoverflow.com/search?q={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}

# Keep shared links clean when they are yanked. The defaults cover UTMs; these
# additions cover the equally common click IDs used by search and newsletters.
c.url.yank_ignored_parameters = [
    "ref",
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    "utm_name",
    "fbclid",
    "gclid",
    "mc_cid",
    "mc_eid",
]


# Conservative privacy defaults which do not usually break modern sites.
c.content.autoplay = False
c.content.geolocation = False
c.content.notifications.enabled = "ask"
c.content.register_protocol_handler = False
c.downloads.location.prompt = True
c.downloads.location.remember = True
c.downloads.location.suggestion = "both"
c.downloads.remove_finished = 15000


# Project Atlas palette. This is read when qutebrowser starts; an already
# running instance keeps its current colors until its next start.
palette = _load_palette()
background = palette["background"]
surface = palette["surface"]
surface_variant = palette["surface_variant"]
hover = palette["hover"]
outline = palette["outline"]
foreground = palette["foreground"]
muted = palette["muted"]
primary = palette["primary"]
on_primary = palette["on_primary"]
secondary = palette["secondary"]
tertiary = palette["tertiary"]
error = palette["error"]
green = palette["green"]

c.fonts.default_family = ["JetBrainsMono Nerd Font"]
c.fonts.default_size = "10pt"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = "dark"

c.colors.completion.category.bg = surface_variant
c.colors.completion.category.border.bottom = outline
c.colors.completion.category.border.top = outline
c.colors.completion.category.fg = secondary
c.colors.completion.even.bg = surface
c.colors.completion.odd.bg = background
c.colors.completion.fg = foreground
c.colors.completion.match.fg = primary
c.colors.completion.item.selected.bg = hover
c.colors.completion.item.selected.border.bottom = primary
c.colors.completion.item.selected.border.top = primary
c.colors.completion.item.selected.fg = foreground
c.colors.completion.item.selected.match.fg = tertiary
c.colors.completion.scrollbar.bg = background
c.colors.completion.scrollbar.fg = outline

c.colors.hints.bg = primary
c.colors.hints.fg = on_primary
c.colors.hints.match.fg = background
c.hints.border = f"1px solid {tertiary}"
c.colors.keyhint.bg = surface_variant
c.colors.keyhint.fg = foreground
c.colors.keyhint.suffix.fg = primary

c.colors.messages.error.bg = error
c.colors.messages.error.border = error
c.colors.messages.error.fg = background
c.colors.messages.info.bg = surface_variant
c.colors.messages.info.border = outline
c.colors.messages.info.fg = foreground
c.colors.messages.warning.bg = tertiary
c.colors.messages.warning.border = tertiary
c.colors.messages.warning.fg = background

c.colors.prompts.bg = surface
c.colors.prompts.border = f"1px solid {outline}"
c.colors.prompts.fg = foreground
c.colors.prompts.selected.bg = primary
c.colors.prompts.selected.fg = on_primary

c.colors.statusbar.normal.bg = background
c.colors.statusbar.normal.fg = muted
c.colors.statusbar.command.bg = surface
c.colors.statusbar.command.fg = foreground
c.colors.statusbar.command.private.bg = surface_variant
c.colors.statusbar.command.private.fg = secondary
c.colors.statusbar.insert.bg = green
c.colors.statusbar.insert.fg = background
c.colors.statusbar.passthrough.bg = secondary
c.colors.statusbar.passthrough.fg = background
c.colors.statusbar.private.bg = primary
c.colors.statusbar.private.fg = on_primary
c.colors.statusbar.progress.bg = primary
c.colors.statusbar.url.fg = foreground
c.colors.statusbar.url.error.fg = error
c.colors.statusbar.url.hover.fg = secondary
c.colors.statusbar.url.success.http.fg = muted
c.colors.statusbar.url.success.https.fg = green
c.colors.statusbar.url.warn.fg = tertiary

c.colors.tabs.bar.bg = background
c.colors.tabs.even.bg = surface
c.colors.tabs.even.fg = muted
c.colors.tabs.odd.bg = surface
c.colors.tabs.odd.fg = muted
c.colors.tabs.selected.even.bg = primary
c.colors.tabs.selected.even.fg = on_primary
c.colors.tabs.selected.odd.bg = primary
c.colors.tabs.selected.odd.fg = on_primary
c.colors.tabs.pinned.even.bg = surface_variant
c.colors.tabs.pinned.even.fg = secondary
c.colors.tabs.pinned.odd.bg = surface_variant
c.colors.tabs.pinned.odd.fg = secondary
c.tabs.padding = {"bottom": 7, "left": 9, "right": 9, "top": 7}
c.statusbar.padding = {"bottom": 5, "left": 8, "right": 8, "top": 5}


# Local leader: comma never conflicts with qutebrowser's default bindings.
config.bind(
    ",a",
    "config-cycle -t -u *://{url:host}/* content.blocking.enabled true false ;; reload",
)
config.bind(",A", "config-cycle -t content.blocking.enabled true false ;; reload")
config.bind(
    ",d",
    "config-cycle -t -u *://{url:host}/* colors.webpage.darkmode.enabled true false ;; reload",
)
config.bind(",u", "adblock-update")
config.bind(",e", "config-edit")
config.bind(",r", "config-source")
config.bind(",p", "open --private")

# Buffers and named sessions. The defaults remain available; these bindings
# make the operations discoverable under one leader without fixing a session
# name in the configuration.
config.bind(",t", "cmd-set-text -s :tab-focus ")
config.bind(",T", "cmd-set-text -s :tab-move ")
config.bind(",c", "tab-clone")
config.bind(",g", "tab-focus last")
config.bind(",s", "cmd-set-text -s :session-save ")
config.bind(",S", "cmd-set-text -s :session-load ")
config.bind(",X", "cmd-set-text -s :session-delete ")

# Links, downloads and external applications. `ym` remains the built-in
# current-page Markdown yank; `;m` adds the same workflow for a hinted link.
config.bind(",y", "yank inline [{title}]({url:yank})")
config.bind(";m", "hint links userscript yank-markdown-link")
config.bind(",o", "download-open")
config.bind(",O", "download-open --dir")
config.bind(",D", "download-clear")
config.bind(",B", "spawn brave {url}")
config.bind(";B", "hint links spawn brave {hint-url}")

# Development keeps the browser as a first-class diagnostic tool. Ctrl-E in a
# text field still opens Neovim through editor.command.
config.bind(",E", "edit-text")
config.bind(",i", "devtools right")
config.bind(",I", "devtools-focus")
config.bind("<Ctrl-Shift-J>", "tab-move +")
config.bind("<Ctrl-Shift-K>", "tab-move -")
