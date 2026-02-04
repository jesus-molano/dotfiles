#!/bin/bash
set -euo pipefail
# Show keybindings from hyprland.conf in rofi

CONFIG="$HOME/.config/hypr/hyprland.conf"

binds=$(awk '
/^\$mainMod/ { mainmod=$3 }
/^\$hyper/ { hyper="Hyper" }
/^bind/ {
    # Extract modifier, key, and action
    line = $0
    sub(/^bind[em]* = /, "", line)

    # Split by comma
    n = split(line, parts, ",")
    if (n < 3) next

    # Clean up
    mod = parts[1]; gsub(/^ +| +$/, "", mod)
    key = parts[2]; gsub(/^ +| +$/, "", key)
    action = parts[3]; gsub(/^ +| +$/, "", action)

    # Replace variable names
    gsub(/\$mainMod/, "ALT", mod)
    gsub(/\$hyper/, "Hyper", mod)

    # Format action
    if (action == "exec") {
        cmd = parts[4]; gsub(/^ +| +$/, "", cmd)
        # Clean command name
        gsub(/.*\//, "", cmd)
        desc = cmd
    } else if (action == "killactive") desc = "Close window"
    else if (action == "movefocus") desc = "Focus " parts[4]
    else if (action == "movewindow") desc = "Move window " parts[4]
    else if (action == "resizeactive") desc = "Resize window"
    else if (action == "workspace") desc = "Workspace " parts[4]
    else if (action == "movetoworkspace") desc = "Move to workspace " parts[4]
    else if (action == "fullscreen") desc = "Fullscreen"
    else if (action == "togglefloating") desc = "Toggle floating"
    else desc = action

    gsub(/^ +| +$/, "", desc)
    printf "%-25s %s\n", mod " + " key, desc
}
' "$CONFIG")

echo "$binds" | rofi -dmenu -p "Keybindings" -i -theme ~/.config/rofi/launchers/type-1/style-2.rasi -theme-str 'window { width: 750px; }'
