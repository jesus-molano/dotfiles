hl.config({
    dwindle = {
        preserve_split = true,
    },
    scrolling = {
        column_width = 0.5,
        focus_fit_method = 1,
        follow_focus = true,
        follow_min_visible = 0.4,
        fullscreen_on_one_column = true,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
        wrap_focus = true,
        wrap_swapcol = true,
        direction = "right",
    },
    misc = {
        col = {
            splash = CACHYLGREEN,
        },
        middle_click_paste = false,
        enable_swallow = true,
        swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
        -- Stable 75 Hz desktop; enable VRR per external output only after a
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
