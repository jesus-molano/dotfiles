#!/bin/bash
set -uo pipefail

# Outputs JSON for waybar custom/network module
# Priority: ethernet > wifi > disconnected

eth_info() {
    local iface ip
    iface=$(nmcli -t -f DEVICE,TYPE,STATE device status | grep "ethernet:connected" | cut -d: -f1 | head -1)
    [[ -z "$iface" ]] && return 1
    ip=$(nmcli -t -f IP4.ADDRESS device show "$iface" 2>/dev/null | head -1 | cut -d: -f2)
    local speed
    speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)
    [[ -n "$speed" ]] && speed="${speed} Mbps" || speed=""
    local tooltip="󰈀  ${iface}\n󰩟  ${ip}"
    [[ -n "$speed" ]] && tooltip+="\n󰓅  ${speed}"
    printf '{"text":"󰈀","tooltip":"%s","class":"ethernet"}\n' "$tooltip"
}

wifi_info() {
    local essid signal ip
    essid=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
    [[ -z "$essid" ]] && return 1
    signal=$(nmcli -t -f active,signal dev wifi | grep "^yes" | cut -d: -f2)
    local iface
    iface=$(nmcli -t -f DEVICE,TYPE,STATE device status | grep "wifi:connected" | cut -d: -f1 | head -1)
    ip=$(nmcli -t -f IP4.ADDRESS device show "$iface" 2>/dev/null | head -1 | cut -d: -f2)
    local icon="󰤨"
    (( signal < 75 )) && icon="󰤥"
    (( signal < 50 )) && icon="󰤢"
    (( signal < 25 )) && icon="󰤟"
    local tooltip="  ${essid}\n󰩟  ${ip}\n󰢮  ${signal}%"
    printf '{"text":"%s","tooltip":"%s","class":"wifi"}\n' "$icon" "$tooltip"
}

if eth_info; then
    exit 0
elif wifi_info; then
    exit 0
else
    echo '{"text":"󰤭","tooltip":"Sin conexión","class":"disconnected"}'
fi
