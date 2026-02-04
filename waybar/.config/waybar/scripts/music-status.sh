#!/usr/bin/env bash
set -uo pipefail

generate_bars() {
    local chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇)
    local n=${#chars[@]}
    echo "${chars[$((RANDOM % n))]}${chars[$((RANDOM % n))]}${chars[$((RANDOM % n))]}"
}

while true; do
    status=$(playerctl status 2>/dev/null)

    case "$status" in
        Playing)
            artist=$(playerctl metadata artist 2>/dev/null)
            title=$(playerctl metadata title 2>/dev/null)
            bars=$(generate_bars)
            printf '{"text": "%s", "tooltip": "%s - %s", "class": "playing"}\n' "$bars" "$title" "$artist"
            sleep 0.3
            ;;
        Paused)
            artist=$(playerctl metadata artist 2>/dev/null)
            title=$(playerctl metadata title 2>/dev/null)
            printf '{"text": "󰏤", "tooltip": "%s - %s (pausado)", "class": "paused"}\n' "$title" "$artist"
            sleep 2
            ;;
        *)
            echo '{"text": "", "class": "stopped"}'
            sleep 2
            ;;
    esac
done
