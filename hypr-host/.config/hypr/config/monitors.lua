-- Generic monitor policy for unknown or changed hardware. Do not infer output
-- names, physical layout, scale or VRR: the generated host fragment can add
-- explicit monitors only after setup has collected those choices.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
    vrr = false,
})
