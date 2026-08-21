-- Portable input baseline. Device-specific settings belong in a generated
-- fragment only after the detector has identified and the user has confirmed
-- the device. This keeps replacement keyboards, mice and touchpads usable.
hl.config({
    input = {
        follow_mouse = 0,
        mouse_refocus = false,
        repeat_delay = 300,
        repeat_rate = 40,
    },
})
