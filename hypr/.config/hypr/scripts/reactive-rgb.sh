#!/usr/bin/env bash
# Reactive RGB - Maps CPU temperature to Catppuccin Mocha colors via OpenRGB
# Launched from Hyprland autostart, runs in background

INTERVAL=5
LAST_COLOR=""

get_cpu_temp() {
    # k10temp Tctl - read from sysfs (millidegrees)
    for f in /sys/class/hwmon/hwmon*/name; do
        if [[ "$(cat "$f" 2>/dev/null)" == "k10temp" ]]; then
            local hwmon_dir
            hwmon_dir="$(dirname "$f")"
            local temp_raw
            temp_raw="$(cat "$hwmon_dir/temp1_input" 2>/dev/null)"
            if [[ -n "$temp_raw" ]]; then
                echo $(( temp_raw / 1000 ))
                return
            fi
        fi
    done
    # Fallback: parse sensors output
    sensors k10temp-pci-00c3 2>/dev/null | awk '/Tctl/ {gsub(/[^0-9.]/, "", $2); printf "%.0f", $2}'
}

temp_to_color() {
    local temp=$1
    if (( temp < 45 )); then
        echo "89B4FA"   # Blue - cool
    elif (( temp < 60 )); then
        echo "94E2D5"   # Teal - normal
    elif (( temp < 72 )); then
        echo "F9E2AF"   # Yellow - warm
    elif (( temp < 80 )); then
        echo "FAB387"   # Peach - hot
    else
        echo "F38BA8"   # Red - critical
    fi
}

apply_color() {
    local color=$1
    # Device indices are hardware-dependent — adjust if USB devices change order
    for d in 0 1 2; do
        openrgb -d "$d" -m static -c "$color" &>/dev/null &
    done
    wait
}

# Wait for OpenRGB server to be ready
sleep 5

while true; do
    temp=$(get_cpu_temp)
    if [[ -n "$temp" ]]; then
        color=$(temp_to_color "$temp")
        if [[ "$color" != "$LAST_COLOR" ]]; then
            if ! apply_color "$color"; then
                sleep 10
                continue
            fi
            LAST_COLOR="$color"
        fi
    fi
    sleep "$INTERVAL"
done
