-- The laptop exposes a controllable internal backlight.
local noctalia = "noctalia msg "

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
