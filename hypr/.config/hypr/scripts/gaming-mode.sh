#!/usr/bin/env bash
STATE_FILE="/tmp/hypr-gaming-mode"

if [[ -f "$STATE_FILE" ]]; then
    hyprctl keyword decoration:blur:enabled true
    hyprctl keyword animations:enabled true
    hyprctl keyword decoration:rounding 10
    rm "$STATE_FILE"
    notify-send -t 2000 "Gaming Mode OFF" "Blur y animaciones restaurados"
else
    hyprctl keyword decoration:blur:enabled false
    hyprctl keyword animations:enabled false
    hyprctl keyword decoration:rounding 0
    touch "$STATE_FILE"
    notify-send -t 2000 "Gaming Mode ON" "Blur y animaciones desactivados"
fi
