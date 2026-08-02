-- The physical Keychron is ANSI/US. Keep US first so bindings resolve against
-- its printed keys, and expose Spanish as an explicit secondary layout.
TERMINAL = "ghostty"
FILE_MANAGER = "dolphin"
BROWSER = "qutebrowser"
EDITOR = "ghostty -e nvim"

-- Group workspaces by the hand that reaches them: Q/W/E/R stay on the left
-- display and U/I/O/P stay on the primary display on the right.
WORKSPACE_MONITORS = {
    [1] = "HDMI-A-1",
    [2] = "HDMI-A-1",
    [3] = "HDMI-A-1",
    [4] = "HDMI-A-1",
    [5] = "HDMI-A-2",
    [6] = "HDMI-A-2",
    [7] = "HDMI-A-2",
    [8] = "HDMI-A-2",
}
WORKSPACE_DEFAULTS = { [1] = true, [5] = true }
WORKSPACE_ICON_OVERRIDES = {
    [1] = "", -- Q: terminal
    [2] = "", -- W: files / directories
    [3] = "", -- E: music
    [4] = "", -- R: communication
    [5] = "", -- U: browser
    [6] = "", -- I: code
    [7] = "", -- O: games
}
MUSIC_WORKSPACE = 3

hl.config({
    input = {
        kb_layout = "us,es",
    },
})

HYPR_BIND("SUPER + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), {
    description = "Alternar teclado inglés/español",
})
