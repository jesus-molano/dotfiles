-- The physical Keychron is ANSI/US. Keep US first so bindings resolve against
-- its printed keys, and expose Spanish as an explicit secondary layout.
TERMINAL = "ghostty"
FILE_MANAGER = "dolphin"
BROWSER = "qutebrowser"
EDITOR = "ghostty -e nvim"

-- With both Philips connected, Q/W/E/R stay on the left and U/I/O/P on the
-- primary display on the right. The shared workspace module collapses all
-- eight onto whichever display remains when either output is disconnected.
WORKSPACE_MONITOR_POLICY = {
    left = "HDMI-A-1",
    right = "HDMI-A-2",
    split_after = 4,
}
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
