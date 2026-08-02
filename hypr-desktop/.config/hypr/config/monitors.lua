-- Hardware report: two Philips 273V7 panels at 1920x1080@60, side by side.
-- HDMI-A-1 is physically left; HDMI-A-2 is the primary display on the right.
-- Workspace ownership is declared separately in user-inputs.lua.
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = "1",
    vrr = false,
})

hl.monitor({
    output = "HDMI-A-2",
    mode = "1920x1080@60",
    position = "1920x0",
    scale = "1",
    vrr = false,
})

-- Safe fallback for temporary or replacement outputs.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
    vrr = false,
})
