-- Input configuration

hl.config({
    input = {
        follow_mouse = 0,
        mouse_refocus = false,
        repeat_delay = 300,
        repeat_rate = 40,
        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
            tap_to_click = true,
        },
    },
    -- Uncomment the section below to enable software cursors; this can help with cursor display or behavior issues
    -- cursor = {
    --     no_hardware_cursors = 1,
    -- },
})

-- Keep only deliberate workspace navigation. Closing windows by gesture is too
-- destructive for a keyboard-first workstation.
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- The built-in touchpad benefits from adaptive acceleration without changing
-- the behaviour of external mice.
hl.device({
    name = "syna7db5:01-06cb:7db7-touchpad",
    accel_profile = "adaptive",
})
