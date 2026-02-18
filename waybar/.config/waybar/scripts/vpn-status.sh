#!/usr/bin/env bash

CONN="Jesus_Molano"

status() {
    if nmcli connection show --active | grep -q "$CONN"; then
        echo '{"text":"󰒃 VPN","class":"connected","tooltip":"WireGuard: conectado"}'
    else
        echo '{"text":"󰒄 VPN","class":"disconnected","tooltip":"WireGuard: desconectado"}'
    fi
}

toggle() {
    if nmcli connection show --active | grep -q "$CONN"; then
        nmcli connection down "$CONN"
    else
        nmcli connection up "$CONN"
    fi
    pkill -RTMIN+9 waybar
}

case "$1" in
    toggle) toggle ;;
    *) status ;;
esac
