hl.config({
    dwindle = {
        preserve_split = true,
    },
    misc = {
        col = {
            splash = CACHYLGREEN,
        },
        middle_click_paste = false,
        enable_swallow = true,
        swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
        -- Stable 60 Hz desktop; enable VRR per external output only after a
        -- physical monitor test.
        vrr = 0,
    },
    xwayland = {
        force_zero_scaling = true
    },
    ecosystem = {
        enforce_permissions = true,
        no_update_news = true,
        no_donation_nag = true,
    },
})

hl.permission({ binary = "/usr/bin/grim", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/bin/noctalia", type = "screencopy", mode = "allow" })
hl.permission({
    binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland",
    type = "screencopy",
    mode = "allow",
})
