#!/usr/bin/env bash
set -uo pipefail

# Music status for Waybar — event-driven via playerctl --follow
# Outputs JSON: {"text": "...", "tooltip": "...", "class": "..."}

BARS_PID=""

cleanup() {
    [[ -n "$BARS_PID" ]] && kill "$BARS_PID" 2>/dev/null
    wait "$BARS_PID" 2>/dev/null
    BARS_PID=""
}
trap cleanup EXIT

generate_bars() {
    local chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇)
    local n=${#chars[@]}
    echo "${chars[$((RANDOM % n))]}${chars[$((RANDOM % n))]}${chars[$((RANDOM % n))]}"
}

start_bars_animation() {
    local artist=$1 title=$2
    stop_bars_animation
    (
        while true; do
            local bars
            bars=$(generate_bars)
            printf '{"text": "%s", "tooltip": "%s - %s", "class": "playing"}\n' "$bars" "$title" "$artist"
            sleep 0.3
        done
    ) &
    BARS_PID=$!
}

stop_bars_animation() {
    if [[ -n "$BARS_PID" ]]; then
        kill "$BARS_PID" 2>/dev/null
        wait "$BARS_PID" 2>/dev/null
        BARS_PID=""
    fi
}

# Wait for playerctl to be available
while ! command -v playerctl &>/dev/null; do
    sleep 5
done

# Use process substitution to avoid subshell (keeps BARS_PID in main shell)
while IFS='|' read -r status artist title; do
    case "$status" in
        Playing)
            start_bars_animation "$artist" "$title"
            ;;
        Paused)
            stop_bars_animation
            printf '{"text": "󰏤", "tooltip": "%s - %s (pausado)", "class": "paused"}\n' "$title" "$artist"
            ;;
        *)
            stop_bars_animation
            echo '{"text": "", "class": "stopped"}'
            ;;
    esac
done < <(playerctl --follow metadata --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null)

# If playerctl --follow exits (no players), show empty and retry
stop_bars_animation
echo '{"text": "", "class": "stopped"}'
