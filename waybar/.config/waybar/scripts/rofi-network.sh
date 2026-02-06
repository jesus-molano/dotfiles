#!/bin/bash
set -uo pipefail

# Unified network management menu via rofi + nmcli (ethernet + wifi)

THEME="$HOME/.config/waybar/scripts/rofi-theme.rasi"
ROFI="rofi -dmenu -i -theme $THEME"

notify() { notify-send -a "Red" "$1" "$2"; }

# ── Ethernet helpers ──

active_ethernet() {
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ethernet | cut -d: -f1
}

eth_iface() {
    nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | grep "ethernet:connected" | cut -d: -f1 | head -1
}

# ── WiFi helpers ──

wifi_status() {
    nmcli -t -f WIFI general 2>/dev/null | head -1
}

active_wifi() {
    nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2
}

scan_and_list() {
    nmcli device wifi rescan 2>/dev/null
    local current
    current=$(active_wifi)

    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | \
        grep -v '^--' | grep -v '^$' | \
        sort -t: -k2 -rn | \
        awk -F: -v cur="$current" '!seen[$1]++ {
            if ($2 >= 75) icon = "󰤨"
            else if ($2 >= 50) icon = "󰤥"
            else if ($2 >= 25) icon = "󰤢"
            else icon = "󰤟"
            lock = ($3 != "" && $3 != "--") ? " 󰌾" : ""
            mark = ($1 == cur) ? " [conectado]" : ""
            if ($1 != "") printf "%s %s%s%s  (%s%%)\n", icon, $1, lock, mark, $2
        }'
}

connect_wifi() {
    local ssid="$1"

    if nmcli -t -f NAME connection show 2>/dev/null | grep -qx "$ssid"; then
        nmcli connection up "$ssid" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            notify "Conectado" "$ssid"
        else
            notify "Error" "No se pudo conectar a $ssid"
        fi
        return
    fi

    local security
    security=$(nmcli -t -f SSID,SECURITY device wifi list 2>/dev/null | grep "^${ssid}:" | head -1 | cut -d: -f2)

    if [[ -n "$security" && "$security" != "--" ]]; then
        local pass
        pass=$(rofi -dmenu -password -p "Contraseña" -theme "$THEME" \
            -theme-str 'entry { placeholder: "Contraseña para '"$ssid"'..."; }')
        [[ -z "$pass" ]] && return
        local tmp_conn
        tmp_conn=$(mktemp /tmp/nm-wifi.XXXXXX)
        chmod 600 "$tmp_conn"
        cat > "$tmp_conn" <<NMCONN
[connection]
id=$ssid
type=wifi
autoconnect=true
[wifi]
mode=infrastructure
ssid=$ssid
[wifi-security]
key-mgmt=wpa-psk
psk=$pass
[ipv4]
method=auto
[ipv6]
method=auto
NMCONN
        nmcli connection load "$tmp_conn" 2>/dev/null
        rm -f "$tmp_conn"
        nmcli connection up "$ssid" 2>/dev/null
    else
        nmcli device wifi connect "$ssid" 2>/dev/null
    fi

    if [[ $? -eq 0 ]]; then
        notify "Conectado" "$ssid"
    else
        notify "Error" "No se pudo conectar a $ssid"
    fi
}

# ── Main menu ──

main_menu() {
    local options=""
    local eth_conn wifi_conn

    eth_conn=$(active_ethernet)
    wifi_conn=$(active_wifi)

    # Ethernet section
    if [[ -n "$eth_conn" ]]; then
        local iface ip speed
        iface=$(eth_iface)
        ip=$(nmcli -t -f IP4.ADDRESS device show "$iface" 2>/dev/null | head -1 | cut -d: -f2)
        speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)
        [[ -n "$speed" ]] && speed="${speed} Mbps" || speed=""
        options+="󰈀 Ethernet [conectado]\n"
        options+="   󰩟  $ip\n"
        [[ -n "$speed" ]] && options+="   󰓅  $speed\n"
        options+="󰈂 Desconectar ethernet\n"
    else
        options+="󰈂 Ethernet desconectado\n"
    fi

    # Separator
    options+="─────────────\n"

    # WiFi section
    local wifi_on
    wifi_on=$(wifi_status)

    if [[ "$wifi_on" != "enabled" ]]; then
        options+="󰤮 Activar WiFi"
    else
        if [[ -n "$wifi_conn" ]]; then
            options+="󰤨 WiFi: $wifi_conn [conectado]\n"
            options+="󰤭 Desconectar WiFi\n"
        fi
        options+="󰤮 Desactivar WiFi\n"
        options+="󰑓 Escanear redes\n"
        options+="$(scan_and_list)"
    fi

    local choice
    choice=$(echo -e "$options" | $ROFI -p "Red")
    [[ -z "$choice" ]] && return

    case "$choice" in
        "─"*)
            return
            ;;
        "   "*)
            return
            ;;
        *"Ethernet desconectado"*)
            return
            ;;
        *"Ethernet"*"conectado"*)
            return
            ;;
        *"Desconectar ethernet"*)
            nmcli connection down "$eth_conn" 2>/dev/null
            notify "Desconectado" "$eth_conn"
            ;;
        *"Activar WiFi"*)
            nmcli radio wifi on
            notify "WiFi" "Activado"
            ;;
        *"Desactivar WiFi"*)
            nmcli radio wifi off
            notify "WiFi" "Desactivado"
            ;;
        *"Desconectar WiFi"*)
            nmcli connection down "$wifi_conn" 2>/dev/null
            notify "Desconectado" "$wifi_conn"
            ;;
        *"Escanear"*)
            nmcli device wifi rescan 2>/dev/null
            sleep 2
            main_menu
            ;;
        *)
            local ssid
            ssid=$(echo "$choice" | sed 's/^[^ ]* //;s/ 󰌾//;s/ \[conectado\]//;s/  (.*//')
            [[ -n "$ssid" ]] && connect_wifi "$ssid"
            ;;
    esac
}

main_menu
