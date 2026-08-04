"""Project Atlas: qutebrowser keyboard-first configuration."""

# Keep per-site permissions and temporary changes made with :set, while this
# file remains the canonical source for the workstation defaults.
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
c.url.default_page = "https://start.duckduckgo.com/"
c.url.start_pages = ["https://start.duckduckgo.com/"]
c.url.searchengines = {
    "DEFAULT": "https://duckduckgo.com/?q={}",
    "aw": "https://wiki.archlinux.org/index.php?search={}",
    "g": "https://www.google.com/search?q={}",
    "gh": "https://github.com/search?q={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}


# Conservative privacy defaults which do not usually break modern sites.
c.content.autoplay = False
c.content.geolocation = False
c.content.notifications.enabled = "ask"
c.content.register_protocol_handler = False
c.downloads.location.prompt = True
c.downloads.remove_finished = 15000


# Project Atlas palette.
background = "#090a0d"
surface = "#14171c"
surface_variant = "#1b1f26"
hover = "#222731"
outline = "#454b57"
foreground = "#f1f3f5"
muted = "#a8afba"
primary = "#ff5b4d"
on_primary = "#180a08"
secondary = "#83a7c4"
tertiary = "#c4a663"
error = "#d86f91"
green = "#73bd8a"

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
c.colors.statusbar.private.bg = surface_variant
c.colors.statusbar.private.fg = secondary
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
config.bind(",a", "config-cycle -t -u *://{url:host}/* content.blocking.enabled true false ;; reload")
config.bind(",A", "config-cycle -t content.blocking.enabled true false ;; reload")
config.bind(",d", "config-cycle -t -u *://{url:host}/* colors.webpage.darkmode.enabled true false ;; reload")
config.bind(",u", "adblock-update")
config.bind(",e", "config-edit")
config.bind(",r", "config-source")
config.bind(",B", "spawn brave {url}")
config.bind(";B", "hint links spawn brave {hint-url}")
config.bind("<Ctrl-Shift-J>", "tab-move +")
config.bind("<Ctrl-Shift-K>", "tab-move -")
