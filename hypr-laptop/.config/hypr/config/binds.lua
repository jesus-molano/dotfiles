-- CachyOS fallback bindings. The personal Alt/Hyper layer lives in
-- user-binds.lua; both files pass through HYPR_BIND so duplicates fail config
-- validation instead of silently shadowing one another.
local main = "SUPER"
local noctalia = "noctalia msg "
local launch = "uwsm app -- "

-- Window management.
HYPR_BIND(main .. " + Escape", hl.dsp.exec_cmd("hyprctl kill"), {
    description = "Seleccionar una ventana para cerrarla",
})
HYPR_BIND(main .. " + Q", hl.dsp.window.close(), {
    description = "Cerrar la ventana activa",
})
HYPR_BIND(main .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }), {
    description = "Alternar ventana flotante",
})
HYPR_BIND(main .. " + D", hl.dsp.window.fullscreen({ mode = 1 }), {
    description = "Maximizar la ventana activa",
})
HYPR_BIND(main .. " + F", hl.dsp.window.fullscreen(), {
    description = "Alternar pantalla completa",
})
HYPR_BIND(main .. " + J", hl.dsp.layout("togglesplit"), {
    description = "Alternar dirección de la división",
})

local directions = {
    Left = "left",
    Right = "right",
    Up = "up",
    Down = "down",
}
for key, direction in pairs(directions) do
    HYPR_BIND(main .. " + " .. key, hl.dsp.focus({ direction = direction }), {
        description = "Mover el foco hacia " .. direction,
    })
end

HYPR_BIND(main .. " + Tab", hl.dsp.exec_cmd(noctalia .. "window-switcher"), {
    description = "Abrir el cambiador de ventanas de Noctalia",
})

local move_directions = {
    Left = "l",
    Right = "r",
    Up = "u",
    Down = "d",
}
for key, direction in pairs(move_directions) do
    HYPR_BIND(main .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }), {
        description = "Mover la ventana hacia " .. direction,
    })
end

HYPR_BIND(main .. " + SHIFT + mouse_up", hl.dsp.window.move({ monitor = "-1" }), {
    description = "Mover ventana al monitor anterior",
})
HYPR_BIND(main .. " + SHIFT + mouse_down", hl.dsp.window.move({ monitor = "+1" }), {
    description = "Mover ventana al monitor siguiente",
})
HYPR_BIND(main .. " + CONTROL + SHIFT + Right", hl.dsp.window.move({ workspace = "m+1" }), {
    description = "Mover ventana al workspace siguiente",
})
HYPR_BIND(main .. " + CONTROL + SHIFT + Left", hl.dsp.window.move({ workspace = "m-1" }), {
    description = "Mover ventana al workspace anterior",
})

HYPR_BIND(main .. " + mouse:272", hl.dsp.window.drag(), {
    description = "Arrastrar la ventana con el ratón",
    mouse = true,
})
HYPR_BIND(main .. " + mouse:273", hl.dsp.window.resize(), {
    description = "Redimensionar la ventana con el ratón",
    mouse = true,
})

-- Applications and panels.
HYPR_BIND(main .. " + Return", hl.dsp.exec_cmd(launch .. TERMINAL), {
    description = "Abrir Ghostty",
})
HYPR_BIND(main .. " + E", hl.dsp.exec_cmd(launch .. FILE_MANAGER), {
    description = "Abrir Dolphin",
})
HYPR_BIND(main .. " + T", hl.dsp.exec_cmd(launch .. EDITOR), {
    description = "Abrir Neovim en Ghostty",
})
HYPR_BIND(main .. " + C", hl.dsp.exec_cmd(launch .. CALCULATOR), {
    description = "Abrir la calculadora",
})
HYPR_BIND("XF86Calculator", hl.dsp.exec_cmd(launch .. CALCULATOR), {
    description = "Abrir la calculadora",
})
HYPR_BIND(main .. " + W", hl.dsp.exec_cmd(launch .. BROWSER), {
    description = "Abrir Brave",
})
HYPR_BIND("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launch .. TERMINAL .. " -e btop"), {
    description = "Abrir el monitor del sistema",
})
HYPR_BIND(main .. " + Z", hl.dsp.exec_cmd(noctalia .. "settings-toggle"), {
    description = "Abrir ajustes de Noctalia",
})
HYPR_BIND(main .. " + X", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center"), {
    description = "Abrir el centro de control",
})
HYPR_BIND(main .. " + Space", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"), {
    description = "Abrir el launcher",
})
HYPR_BIND(main .. " + period", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher /emo"), {
    description = "Abrir el selector de emoji",
})
HYPR_BIND(main .. " + L", hl.dsp.exec_cmd(noctalia .. "session lock"), {
    description = "Bloquear la sesión",
})
HYPR_BIND(main .. " + ALT + C", hl.dsp.exec_cmd(noctalia .. "panel-toggle session"), {
    description = "Abrir el menú de sesión",
})

-- Hardware controls.
HYPR_BIND("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctalia .. "volume-up"), {
    description = "Subir volumen",
    locked = true,
    repeating = true,
})
HYPR_BIND("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctalia .. "volume-down"), {
    description = "Bajar volumen",
    locked = true,
    repeating = true,
})
HYPR_BIND("XF86AudioMute", hl.dsp.exec_cmd(noctalia .. "volume-mute"), {
    description = "Silenciar audio",
    locked = true,
})
HYPR_BIND("XF86AudioMicMute", hl.dsp.exec_cmd(noctalia .. "mic-mute"), {
    description = "Silenciar micrófono",
    locked = true,
})
HYPR_BIND("XF86AudioPlay", hl.dsp.exec_cmd(noctalia .. "media toggle"), {
    description = "Reproducir o pausar",
    locked = true,
})
HYPR_BIND("XF86AudioPause", hl.dsp.exec_cmd(noctalia .. "media toggle"), {
    description = "Reproducir o pausar",
    locked = true,
})
HYPR_BIND("XF86AudioNext", hl.dsp.exec_cmd(noctalia .. "media next"), {
    description = "Pista siguiente",
    locked = true,
})
HYPR_BIND("XF86AudioPrev", hl.dsp.exec_cmd(noctalia .. "media previous"), {
    description = "Pista anterior",
    locked = true,
})
HYPR_BIND("XF86MonBrightnessUp", hl.dsp.exec_cmd(noctalia .. "brightness-up"), {
    description = "Subir brillo",
    locked = true,
    repeating = true,
})
HYPR_BIND("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctalia .. "brightness-down"), {
    description = "Bajar brillo",
    locked = true,
    repeating = true,
})

-- Utilities and dynamic workspace navigation.
HYPR_BIND(main .. " + P", hl.dsp.exec_cmd("hyprpicker -a -n"), {
    description = "Copiar un color de la pantalla",
})
HYPR_BIND("Print", hl.dsp.exec_cmd(noctalia .. "screenshot-region"), {
    description = "Capturar una región",
})
HYPR_BIND(main .. " + Print", hl.dsp.exec_cmd(noctalia .. "screenshot-fullscreen"), {
    description = "Capturar la pantalla",
})
HYPR_BIND(main .. " + SHIFT + W", hl.dsp.exec_cmd(noctalia .. "panel-toggle wallpaper"), {
    description = "Abrir selector de fondo",
})
HYPR_BIND(main .. " + V", hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard"), {
    description = "Abrir historial del portapapeles",
})
HYPR_BIND(main .. " + A", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center notifications"), {
    description = "Abrir notificaciones",
})
HYPR_BIND(main .. " + CONTROL + Right", hl.dsp.focus({ workspace = "m+1" }), {
    description = "Ir al workspace siguiente",
})
HYPR_BIND(main .. " + CONTROL + Left", hl.dsp.focus({ workspace = "m-1" }), {
    description = "Ir al workspace anterior",
})
HYPR_BIND(main .. " + CONTROL + Down", hl.dsp.focus({ workspace = "emptym" }), {
    description = "Ir a un workspace vacío",
})
HYPR_BIND(main .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }), {
    description = "Ir al workspace anterior con la rueda",
})
HYPR_BIND(main .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }), {
    description = "Ir al workspace siguiente con la rueda",
})
HYPR_BIND(main .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratchpad" }), {
    description = "Enviar ventana al scratchpad",
})
HYPR_BIND(main .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), {
    description = "Alternar scratchpad",
})
