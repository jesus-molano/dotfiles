-- Global shortcuts and hardware controls shared by laptop and desktop. All
-- bindings pass through HYPR_BIND so duplicates fail config validation instead
-- of silently shadowing one another. Display brightness stays in each profile.
local main = "SUPER"
local noctalia = "noctalia msg "
local launch = "uwsm app -- "

-- Deliberate global shortcuts.
HYPR_BIND(main .. " + V", hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard"), {
    description = "Abrir historial del portapapeles",
})
HYPR_BIND("Print", hl.dsp.exec_cmd(noctalia .. "screenshot-region"), {
    description = "Capturar una región",
})
HYPR_BIND("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launch .. TERMINAL .. " -e btop"), {
    description = "Abrir el monitor del sistema",
})
HYPR_BIND("XF86Calculator", hl.dsp.exec_cmd(launch .. CALCULATOR), {
    description = "Abrir la calculadora",
})

-- Zoom de accesibilidad portado de cachyos-hypr-noctalia 1.2.4. Se limita al
-- intervalo admitido por Hyprland y conserva tanto la fila principal como el
-- teclado numérico.
local function change_zoom(delta)
    local current = hl.get_config("cursor:zoom_factor")
    local target = math.max(1.0, math.min(3.0, current + delta))
    hl.config({ cursor = { zoom_factor = target } })
end
HYPR_BIND(main .. " + Minus", function() change_zoom(-0.3) end, {
    description = "Reducir el zoom",
    repeating = true,
})
HYPR_BIND(main .. " + Plus", function() change_zoom(0.3) end, {
    description = "Aumentar el zoom",
    repeating = true,
})
HYPR_BIND(main .. " + code:82", function() change_zoom(-0.3) end, {
    description = "Reducir el zoom con teclado numérico",
    repeating = true,
})
HYPR_BIND(main .. " + code:86", function() change_zoom(0.3) end, {
    description = "Aumentar el zoom con teclado numérico",
    repeating = true,
})

-- Hardware controls remain available while the session is locked. Volume and
-- brightness repeat while their key is held.
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
