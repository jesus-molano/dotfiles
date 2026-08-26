-- Personal Alt/Hyper keyboard workflow.
-- Caps Lock is converted by Kanata: tap = Escape, hold = Hyper.

local alt = "ALT"
local hyper = "CONTROL + ALT + SUPER + SHIFT"
local launch = "uwsm app -- "
local noctalia = "noctalia msg "

local function bind(keys, dispatcher, description, options)
    options = options or {}
    options.description = description
    return HYPR_BIND(keys, dispatcher, options)
end

-- Vim-style focus, movement and resize.
local directions = {
    H = { focus = "left", move = "l", label = "left", resize = { x = -40, y = 0 } },
    J = { focus = "down", move = "d", label = "down", resize = { x = 0, y = 40 } },
    K = { focus = "up", move = "u", label = "up", resize = { x = 0, y = -40 } },
    L = { focus = "right", move = "r", label = "right", resize = { x = 40, y = 0 } },
}
for key, direction in pairs(directions) do
    bind(alt .. " + " .. key, hl.dsp.focus({ direction = direction.focus }),
        "Move focus " .. direction.label)
    bind(alt .. " + SHIFT + " .. key,
        hl.dsp.window.move({ direction = direction.move, group_aware = true }),
        "Move window " .. direction.label)
    bind(alt .. " + CONTROL + " .. key,
        hl.dsp.window.resize({ x = direction.resize.x, y = direction.resize.y, relative = true }),
        "Resize window " .. direction.label, { repeating = true })
end

bind(alt .. " + X", hl.dsp.window.close(), "Close active window")
bind(alt .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }),
    "Maximize active window")
bind(alt .. " + F", hl.dsp.window.float({ action = "toggle" }), "Toggle floating window")
bind(hyper .. " + D", hl.dsp.layout("togglesplit"), "Toggle split direction")
bind(hyper .. " + comma", hl.dsp.layout("move -col"),
    "Move one column left in the scrolling layout")
bind(hyper .. " + period", hl.dsp.layout("move +col"),
    "Move one column right in the scrolling layout")
bind(hyper .. " + semicolon", hl.dsp.layout("colresize +conf"),
    "Toggle scrolling column width")
bind(hyper .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }),
    "Toggle fullscreen")

-- Eight workspaces split between both hands on the upper letter row.
local workspace_keys = { "Q", "W", "E", "R", "U", "I", "O", "P" }
for workspace, key in ipairs(workspace_keys) do
    bind(alt .. " + " .. key, hl.dsp.focus({ workspace = workspace }),
        "Go to workspace " .. workspace)
    bind(alt .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }),
        "Move window to workspace " .. workspace)
end

bind(alt .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), "Toggle scratchpad")
bind(alt .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratchpad" }),
    "Move window to scratchpad")
bind(alt .. " + A", hl.dsp.workspace.toggle_special("ai"),
    "Toggle AI scratchpad")
bind(alt .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:ai" }),
    "Move window to AI scratchpad")
bind(alt .. " + Z", hl.dsp.workspace.toggle_special("logs"),
    "Toggle logs scratchpad")
bind(alt .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:logs" }),
    "Move window to logs scratchpad")

-- Window groups/tabs.
bind(alt .. " + G", hl.dsp.group.toggle(), "Toggle window group")
bind(alt .. " + N", hl.dsp.group.next(), "Focus next window in group")
bind(alt .. " + SHIFT + N", hl.dsp.group.prev(), "Focus previous window in group")

-- Hyper application, layout and Noctalia layer.
bind(hyper .. " + Return", hl.dsp.exec_cmd(launch .. TERMINAL), "Open Ghostty")
bind(hyper .. " + B", hl.dsp.exec_cmd(launch .. BROWSER), "Open Brave")
bind(hyper .. " + E", hl.dsp.exec_cmd(launch .. FILE_MANAGER), "Open Dolphin")
bind(hyper .. " + Y", hl.dsp.exec_cmd(launch .. TERMINAL .. " -e fish -ic y"),
    "Open Yazi in Ghostty")
bind(hyper .. " + O", hl.dsp.exec_cmd("hypr-orca"), "Focus or open Orca")
bind(hyper .. " + M", hl.dsp.exec_cmd("hypr-spotify"), "Focus or open Spotify")
bind(hyper .. " + S", hl.dsp.exec_cmd("hypr-stremio"), "Focus or open Stremio")
bind(alt .. " + Space", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"), "Open launcher")
bind(hyper .. " + Space", hl.dsp.exec_cmd(noctalia .. "panel-open launcher /cmd"),
    "Open launcher commands")
bind(hyper .. " + J", hl.dsp.exec_cmd(noctalia .. "panel-open launcher /proj"),
    "Open launcher projects")
bind(hyper .. " + V", hl.dsp.exec_cmd(noctalia .. "panel-open launcher /media"),
    "Open launcher media")
bind(hyper .. " + bracketleft", hl.dsp.exec_cmd(noctalia .. "wallpaper-previous"),
    "Use previous theme wallpaper")
bind(hyper .. " + bracketright", hl.dsp.exec_cmd(noctalia .. "wallpaper-next"),
    "Use next theme wallpaper")
bind(hyper .. " + T", hl.dsp.exec_cmd(noctalia .. "panel-open launcher /appearance"),
    "Open appearance panel")
bind(hyper .. " + A", hl.dsp.exec_cmd("desktop-launcher open timer"),
    "Open timer")
bind(hyper .. " + N", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center notifications"),
    "Open notifications")
bind(hyper .. " + H", hl.dsp.exec_cmd("cycle-desktop-audio-output"),
    "Use next audio output")
bind(hyper .. " + P", hl.dsp.exec_cmd("capture-context --focus orca"),
    "Capture a region and prepare context for Orca")
bind(hyper .. " + Q", hl.dsp.exec_cmd(noctalia .. "panel-toggle session"), "Open session menu")
bind(hyper .. " + L", hl.dsp.exec_cmd(noctalia .. "session lock"), "Lock session")
bind(hyper .. " + K", hl.dsp.exec_cmd("hyprpicker -a -n"), "Pick and copy a color")
bind(hyper .. " + 1", hl.dsp.exec_cmd(launch .. "1password"), "Open 1Password")
bind(hyper .. " + C", hl.dsp.exec_cmd(noctalia .. "caffeine-toggle"), "Toggle caffeine")
bind(hyper .. " + I", hl.dsp.exec_cmd("desktop-focus-mode toggle"),
    "Toggle focus mode")
bind(hyper .. " + U", hl.dsp.exec_cmd("desktop-focus-mode demo-toggle"),
    "Toggle demo mode with recording")
bind(hyper .. " + 7", hl.dsp.exec_cmd("hypr-keybind-help"), "Toggle keybindings panel")

-- Alt+Tab has one owner: Noctalia.
bind(alt .. " + TAB", hl.dsp.exec_cmd(noctalia .. "window-switcher"),
    "Open Noctalia window switcher")

-- Mouse workflow retained as a secondary path.
bind(alt .. " + mouse:272", hl.dsp.window.drag(), "Drag window", { mouse = true })
bind(alt .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })
