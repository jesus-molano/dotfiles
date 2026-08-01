-- Personal keyboard workflow layered on top of CachyOS/Noctalia defaults.
-- Caps Lock is converted by Kanata: tap = Escape, hold = Hyper.

local alt = "ALT"
local hyper = "CONTROL + ALT + SUPER + SHIFT"
local launch = "uwsm app -- "
local noctalia = "noctalia msg "

-- Primary application search.
hl.bind(alt .. " + SPACE", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"))

-- Vim-style focus, movement and resize.
hl.bind(alt .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(alt .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(alt .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(alt .. " + L", hl.dsp.focus({ direction = "right" }))

hl.bind(alt .. " + SHIFT + H", hl.dsp.exec_raw("movewindoworgroup", "l"))
hl.bind(alt .. " + SHIFT + J", hl.dsp.exec_raw("movewindoworgroup", "d"))
hl.bind(alt .. " + SHIFT + K", hl.dsp.exec_raw("movewindoworgroup", "u"))
hl.bind(alt .. " + SHIFT + L", hl.dsp.exec_raw("movewindoworgroup", "r"))

hl.bind(alt .. " + CONTROL + H", hl.dsp.exec_raw("resizeactive", "-40 0"), { repeating = true })
hl.bind(alt .. " + CONTROL + J", hl.dsp.exec_raw("resizeactive", "0 40"),  { repeating = true })
hl.bind(alt .. " + CONTROL + K", hl.dsp.exec_raw("resizeactive", "0 -40"), { repeating = true })
hl.bind(alt .. " + CONTROL + L", hl.dsp.exec_raw("resizeactive", "40 0"),  { repeating = true })

hl.bind(alt .. " + X", hl.dsp.window.close())
hl.bind(alt .. " + M", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(alt .. " + F", hl.dsp.window.float({ action = "toggle" }))

-- Eight workspaces on the home row, preserving the previous muscle memory.
local workspace_keys = { "Q", "W", "E", "R", "U", "I", "O", "P" }
for workspace, key in ipairs(workspace_keys) do
    hl.bind(alt .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(alt .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(alt .. " + grave", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(alt .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratchpad" }))

-- Window groups/tabs.
hl.bind(alt .. " + G", hl.dsp.group.toggle())
hl.bind(alt .. " + N", hl.dsp.group.next())
hl.bind(alt .. " + SHIFT + N", hl.dsp.group.prev())

-- Hyper application layer.
hl.bind(hyper .. " + Return", hl.dsp.exec_cmd(launch .. TERMINAL))
hl.bind(hyper .. " + B", hl.dsp.exec_cmd(launch .. BROWSER))
hl.bind(hyper .. " + E", hl.dsp.exec_cmd(launch .. FILE_MANAGER))
hl.bind(hyper .. " + SHIFT + E", hl.dsp.exec_cmd(launch .. "thunar"))
hl.bind(hyper .. " + N", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center notifications"))
hl.bind(hyper .. " + P", hl.dsp.exec_cmd(noctalia .. "screenshot-region"))
hl.bind(hyper .. " + Q", hl.dsp.exec_cmd(noctalia .. "panel-toggle session"))
hl.bind(hyper .. " + L", hl.dsp.exec_cmd(noctalia .. "session lock"))
hl.bind(hyper .. " + period", hl.dsp.exec_cmd(launch .. TERMINAL .. " -e codex"))
hl.bind(hyper .. " + 1", hl.dsp.exec_cmd(launch .. "1password"))
hl.bind(hyper .. " + K", hl.dsp.exec_cmd("hyprpicker -a -n"))
hl.bind(alt .. " + TAB", hl.dsp.exec_cmd(noctalia .. "window-switcher"))

-- Mouse workflow retained from the old configuration.
hl.bind(alt .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(alt .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
