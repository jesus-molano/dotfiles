-- Personal keyboard workflow layered on top of the vendored CachyOS base.
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
    H = { focus = "left", move = "l", resize = "-40 0" },
    J = { focus = "down", move = "d", resize = "0 40" },
    K = { focus = "up", move = "u", resize = "0 -40" },
    L = { focus = "right", move = "r", resize = "40 0" },
}
for key, direction in pairs(directions) do
    bind(alt .. " + " .. key, hl.dsp.focus({ direction = direction.focus }),
        "Mover foco hacia " .. direction.focus)
    bind(alt .. " + SHIFT + " .. key, hl.dsp.exec_raw("movewindoworgroup", direction.move),
        "Mover ventana hacia " .. direction.focus)
    bind(alt .. " + CONTROL + " .. key, hl.dsp.exec_raw("resizeactive", direction.resize),
        "Redimensionar ventana hacia " .. direction.focus, { repeating = true })
end

bind(alt .. " + X", hl.dsp.window.close(), "Cerrar la ventana activa")
bind(alt .. " + M", hl.dsp.window.fullscreen({ mode = 1 }), "Maximizar la ventana activa")
bind(alt .. " + F", hl.dsp.window.float({ action = "toggle" }), "Alternar ventana flotante")

-- Eight workspaces on the home row.
local workspace_keys = { "Q", "W", "E", "R", "U", "I", "O", "P" }
for workspace, key in ipairs(workspace_keys) do
    bind(alt .. " + " .. key, hl.dsp.focus({ workspace = workspace }),
        "Ir al workspace " .. workspace)
    bind(alt .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }),
        "Enviar ventana al workspace " .. workspace)
end

bind(alt .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), "Alternar scratchpad")
bind(alt .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratchpad" }),
    "Enviar ventana al scratchpad")

-- Window groups/tabs.
bind(alt .. " + G", hl.dsp.group.toggle(), "Alternar grupo de ventanas")
bind(alt .. " + N", hl.dsp.group.next(), "Ir a la siguiente ventana del grupo")
bind(alt .. " + SHIFT + N", hl.dsp.group.prev(), "Ir a la anterior ventana del grupo")

-- Hyper application and Noctalia layer.
bind(hyper .. " + Return", hl.dsp.exec_cmd(launch .. TERMINAL), "Abrir Ghostty")
bind(hyper .. " + B", hl.dsp.exec_cmd(launch .. BROWSER), "Abrir Brave")
bind(hyper .. " + E", hl.dsp.exec_cmd(launch .. FILE_MANAGER), "Abrir Dolphin")
bind(hyper .. " + O", hl.dsp.exec_cmd("hypr-orca"), "Enfocar o abrir Orca")
bind(hyper .. " + Space", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"), "Abrir launcher")
bind(hyper .. " + N", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center notifications"),
    "Abrir notificaciones")
bind(hyper .. " + P", hl.dsp.exec_cmd(noctalia .. "screenshot-region"), "Capturar una región")
bind(hyper .. " + Q", hl.dsp.exec_cmd(noctalia .. "panel-toggle session"), "Abrir menú de sesión")
bind(hyper .. " + L", hl.dsp.exec_cmd(noctalia .. "session lock"), "Bloquear la sesión")
bind(hyper .. " + K", hl.dsp.exec_cmd("hyprpicker -a -n"), "Seleccionar y copiar un color")
bind(hyper .. " + 1", hl.dsp.exec_cmd(launch .. "1password"), "Abrir 1Password")
bind(hyper .. " + C", hl.dsp.exec_cmd(noctalia .. "caffeine-toggle"), "Alternar cafeína")
bind(hyper .. " + 7", hl.dsp.exec_cmd("hypr-keybind-help"), "Mostrar ayuda de atajos")

-- Alt+Tab has one owner: Noctalia.
bind(alt .. " + TAB", hl.dsp.exec_cmd(noctalia .. "window-switcher"),
    "Abrir el cambiador de ventanas de Noctalia")

-- Mouse workflow retained as a secondary path.
bind(alt .. " + mouse:272", hl.dsp.window.drag(), "Arrastrar ventana", { mouse = true })
bind(alt .. " + mouse:273", hl.dsp.window.resize(), "Redimensionar ventana", { mouse = true })
