#!/bin/bash
set -euo pipefail
# Translate text between English and Spanish using translate-shell + rofi

ROFI_THEME="$HOME/.config/rofi/launchers/type-1/style-2.rasi"
ROFI_OVERRIDE='window { width: 750px; }'

translate() {
    local text="$1"
    local result
    result=$(timeout 10s trans -b :es "$text" 2>/dev/null)
    if [[ "${result,,}" == "${text,,}" ]]; then
        result=$(timeout 10s trans -b :en "$text" 2>/dev/null)
    fi
    echo "$result"
}

if [[ "${1:-}" == "clipboard" ]]; then
    text=$(wl-paste -p 2>/dev/null) || text=""
    [[ -z "$text" ]] && text=$(wl-paste 2>/dev/null) || true
    if [[ -z "$text" ]]; then
        notify-send -t 3000 -i dialog-warning "Translate" "Clipboard is empty"
        exit 0
    fi
    result=$(translate "$text")
    wl-copy "$result"
    notify-send -t 5000 -i accessories-dictionary "Translate" "$result"
else
    text=$(rofi -dmenu -p "Translate" -theme "$ROFI_THEME" -theme-str "$ROFI_OVERRIDE") || exit 0
    [[ -z "$text" ]] && exit 0
    result=$(translate "$text")
    wl-copy "$result"
    echo "$result" | rofi -dmenu -p "Result" -theme "$ROFI_THEME" -theme-str "$ROFI_OVERRIDE" || true
fi
