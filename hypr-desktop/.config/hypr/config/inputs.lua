-- Desktop input: Keychron K2 keyboard and Logitech M720 mouse. The hardware
-- report contains no touchpad or touch device, so no touchpad policy is set.
hl.config({
    input = {
        follow_mouse = 0,
        mouse_refocus = false,
        repeat_delay = 300,
        repeat_rate = 40,
    },
})

-- Runtime identifier reported by `hyprctl devices -j` for the M720 mouse.
hl.device({
    name = "logitech-m720-triathlon-multi-device-mouse-1",
    accel_profile = "flat",
})
