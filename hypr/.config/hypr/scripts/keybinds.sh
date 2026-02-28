#!/bin/bash
set -uo pipefail
# Show keybindings from hyprland.conf in rofi

CONFIG="$HOME/.config/hypr/hyprland.conf"

binds=$(awk '
/^\$mainMod/ { mainmod=$3 }
/^\$hyper/ { hyper="Hyper" }
/^bind/ {
    line = $0
    sub(/^bind[eml]* = /, "", line)

    n = split(line, parts, ",")
    if (n < 3) next

    mod = parts[1]; gsub(/^ +| +$/, "", mod)
    key = parts[2]; gsub(/^ +| +$/, "", key)
    action = parts[3]; gsub(/^ +| +$/, "", action)

    # Replace variable names
    gsub(/\$mainMod/, "ALT", mod)
    gsub(/\$hyper/, "Hyper", mod)

    # Friendly key names
    gsub(/XF86AudioRaiseVolume/, "Vol+", key)
    gsub(/XF86AudioLowerVolume/, "Vol-", key)
    gsub(/XF86AudioMute/, "Mute", key)
    gsub(/XF86AudioPlay/, "Play", key)
    gsub(/XF86AudioNext/, "Next", key)
    gsub(/XF86AudioPrev/, "Prev", key)
    gsub(/mouse:272/, "LMB", key)
    gsub(/mouse:273/, "RMB", key)
    gsub(/RETURN/, "Enter", key)
    gsub(/grave/, "`", key)

    if (action == "exec") {
        cmd = ""; for (i=4;i<=n;i++) cmd = cmd (i>4?",":"") parts[i]
        gsub(/^ +| +$/, "", cmd)

        # Known command mappings
        if      (cmd ~ /launcher\.sh/)                desc = "App launcher"
        else if (cmd ~ /powermenu\.sh/)                desc = "Power menu"
        else if (cmd ~ /keybinds\.sh/)                 desc = "Keybindings"
        else if (cmd ~ /claude-skills\.sh/)            desc = "Claude skills"
        else if (cmd ~ /nvim-keys\.sh/)                desc = "Neovim keys"
        else if (cmd ~ /translate\.sh clipboard/)      desc = "Translate clipboard"
        else if (cmd ~ /translate\.sh/)                desc = "Translate"
        else if (cmd ~ /super-copy\.sh/)               desc = "Super copy"
        else if (cmd ~ /super-paste\.sh/)              desc = "Super paste"
        else if (cmd ~ /audio-toggle\.sh/)             desc = "Audio toggle"
        else if (cmd ~ /gaming-mode\.sh/)              desc = "Gaming mode"
        else if (cmd ~ /raise-or-run\.sh.*webstorm/)   desc = "WebStorm"
        else if (cmd ~ /raise-or-run\.sh.*slack/)      desc = "Slack"
        else if (cmd ~ /raise-or-run\.sh.*youtube/)    desc = "YouTube Music"
        else if (cmd ~ /raise-or-run\.sh.*steam/)      desc = "Steam"
        else if (cmd ~ /raise-or-run\.sh.*discord/)    desc = "Discord"
        else if (cmd ~ /raise-or-run\.sh.*1password/)  desc = "1Password"
        else if (cmd ~ /ghostty.*clipse/)              desc = "Clipboard manager"
        else if (cmd ~ /ghostty/)                      desc = "Terminal"
        else if (cmd ~ /swaync-client/)                desc = "Notifications"
        else if (cmd ~ /hyprshot/)                     desc = "Screenshot"
        else if (cmd ~ /hyprlock/)                     desc = "Lock screen"
        else if (cmd ~ /hyprpicker/)                   desc = "Color picker"
        else if (cmd ~ /switchxkblayout/)              desc = "Switch keyboard layout"
        else if (cmd ~ /google-chrome/)                desc = "Chrome"
        else if (cmd ~ /thunar/)                       desc = "File manager"
        else if (cmd ~ /wpctl.*set-volume.*\+/)        desc = "Volume up"
        else if (cmd ~ /wpctl.*set-volume.*-/)         desc = "Volume down"
        else if (cmd ~ /wpctl.*set-mute/)              desc = "Toggle mute"
        else if (cmd ~ /playerctl play-pause/)         desc = "Play / Pause"
        else if (cmd ~ /playerctl next/)               desc = "Next track"
        else if (cmd ~ /playerctl previous/)           desc = "Previous track"
        else { gsub(/.*\//, "", cmd); desc = cmd }
    }
    else if (action == "killactive")              desc = "Close window"
    else if (action == "movefocus")             { d=parts[4]; gsub(/^ +/,"",d); desc = "Focus " d }
    else if (action == "movewindow")            { d=parts[4]; gsub(/^ +/,"",d); desc = "Move window" (d?(" " d):"") }
    else if (action == "resizeactive")            desc = "Resize window"
    else if (action == "resizewindow")            desc = "Resize window (mouse)"
    else if (action == "workspace")             { d=parts[4]; gsub(/^ +/,"",d); desc = "Workspace " d }
    else if (action == "movetoworkspace")       { d=parts[4]; gsub(/^ +/,"",d); desc = "Move to " d }
    else if (action == "movetoworkspacesilent") { d=parts[4]; gsub(/^ +/,"",d); desc = "Move to workspace " d }
    else if (action == "swapactiveworkspaces")     desc = "Swap monitors"
    else if (action == "togglespecialworkspace")    desc = "Toggle scratchpad"
    else if (action == "changegroupactive")     { d=parts[4]; desc = "Group " (d~/f/?"next":"prev") }
    else if (action == "togglegroup")              desc = "Toggle group"
    else if (action == "movewindoworgroup")     { d=parts[4]; gsub(/^ +/,"",d); desc = "Move window/group " d }
    else if (action ~ /hyprexpo/)                  desc = "Expo view"
    else if (action == "fullscreen")            { d=parts[4]; gsub(/^ +/,"",d); desc = (d=="1"?"Maximize":"Fullscreen") }
    else if (action == "togglefloating")           desc = "Toggle floating"
    else desc = action

    gsub(/^ +| +$/, "", desc)
    if (mod == "") printf "%-25s %s\n", key, desc
    else printf "%-25s %s\n", mod " + " key, desc
}
' "$CONFIG")

echo "$binds" | rofi -dmenu -p "Keybindings" -i \
    -theme ~/.config/rofi/launchers/type-1/style-2.rasi \
    -theme-str 'window { width: 750px; }'
