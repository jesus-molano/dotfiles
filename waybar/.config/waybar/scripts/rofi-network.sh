#!/bin/bash
set -uo pipefail

# Network management menu via rofi + nmcli

THEME="$HOME/.config/waybar/scripts/rofi-theme.rasi"
ROFI="rofi -dmenu -i -theme $THEME"

notify() { notify-send -a "Red" "$1" "$2"; }

active_ethernet() {
    nmcli -t -f NAME,TYPE connection show --active | grep ethernet | cut -d: -f1
}

active_iface() {
    nmcli -t -f DEVICE,TYPE device status | grep ethernet | cut -d: -f1 | head -1
}

connection_details() {
    local iface
    iface=$(active_iface)
    [[ -z "$iface" ]] && return

    local ip speed
    ip=$(nmcli -t -f IP4.ADDRESS device show "$iface" 2>/dev/null | head -1 | cut -d: -f2)
    speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)
    [[ -n "$speed" ]] && speed="${speed} Mbps" || speed="desconocida"

    echo "󰩟  $ip"
    echo "󰓅  $speed"
}

saved_profiles() {
    nmcli -t -f NAME,TYPE connection show | grep ethernet | cut -d: -f1
}

main_menu() {
    local current
    current=$(active_ethernet)

    local options=""

    if [[ -n "$current" ]]; then
        local details
        details=$(connection_details)
        options+="󰈀 $current [conectado]\n"
        if [[ -n "$details" ]]; then
            while IFS= read -r line; do
                options+="   $line\n"
            done <<< "$details"
        fi
        options+="󰈂 Desconectar\n"
    else
        options+="󰈂 Sin conexión\n"
    fi

    options+="󰑓 Reiniciar red"

    # Add saved profiles (excluding active)
    local profiles
    profiles=$(saved_profiles)
    if [[ -n "$profiles" ]]; then
        while IFS= read -r name; do
            [[ -z "$name" ]] && continue
            [[ "$name" == "$current" ]] && continue
            options+="\n󰌘 $name"
        done <<< "$profiles"
    fi

    local choice
    choice=$(echo -e "$options" | $ROFI -p "Red")
    [[ -z "$choice" ]] && return

    case "$choice" in
        *"Desconectar"*)
            nmcli connection down "$current" 2>/dev/null
            notify "Desconectado" "$current"
            ;;
        *"Reiniciar"*)
            notify "Reiniciando..." "Interfaz de red"
            local iface
            iface=$(active_iface)
            if [[ -n "$iface" ]]; then
                nmcli device disconnect "$iface" 2>/dev/null
                sleep 1
                nmcli device connect "$iface" 2>/dev/null
                notify "Red reiniciada" "$iface"
            else
                nmcli networking off 2>/dev/null
                sleep 1
                nmcli networking on 2>/dev/null
                notify "Red reiniciada" ""
            fi
            ;;
        *"Sin conexión"*)
            return
            ;;
        *"conectado"*)
            return
            ;;
        "   "*)
            return
            ;;
        *)
            local profile
            profile=$(echo "$choice" | sed 's/^[^ ]* //')
            nmcli connection up "$profile" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                notify "Conectado" "$profile"
            else
                notify "Error" "No se pudo conectar a $profile"
            fi
            ;;
    esac
}

main_menu
