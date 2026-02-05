#!/bin/bash
# wait-monitor.sh — espera hasta 10s a que aparezca el segundo monitor, si no, fuerza reload
for i in $(seq 1 10); do
    count=$(hyprctl monitors -j | jq length)
    [ "$count" -ge 2 ] && exit 0
    sleep 1
done
hyprctl reload
