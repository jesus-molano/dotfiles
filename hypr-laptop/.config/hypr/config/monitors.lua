-- Dynamic fallback for occasional hot-plugged outputs. Keep the known laptop
-- panel at its current 1.25 scale so deploying this profile cannot make the
-- whole desktop unexpectedly smaller.
hl.monitor({
    output    = "",
    mode      = "preferred",
    position  = "auto",
    scale     = "1",
    vrr       = false,
})

hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = "1.25",
    vrr      = false,
})
