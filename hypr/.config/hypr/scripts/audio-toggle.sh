#!/usr/bin/env bash
current=$(pactl get-default-sink)
sinks=($(pactl list short sinks | awk '{print $2}'))

for i in "${!sinks[@]}"; do
    if [[ "${sinks[$i]}" == "$current" ]]; then
        next=$(( (i + 1) % ${#sinks[@]} ))
        pactl set-default-sink "${sinks[$next]}"
        desc=$(pactl list sinks | grep -A1 "Name: ${sinks[$next]}" | grep Description | sed 's/.*Description: //')
        notify-send -t 2000 -i audio-speakers "Audio" "$desc"
        exit 0
    fi
done
