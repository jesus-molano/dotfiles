#!/bin/bash
set -uo pipefail

# WiFi management menu via rofi + nmcli

THEME="$HOME/.config/waybar/scripts/rofi-theme.rasi"
ROFI="rofi -dmenu -i -theme $THEME"

notify() { notify-send -a "WiFi" "$1" "$2"; }

get_status() {
    nmcli -t -f WIFI general | head -1
}

toggle_wifi() {
    if [[ "$(get_status)" == "enabled" ]]; then
        nmcli radio wifi off
        notify "WiFi" "Desactivado"
    else
        nmcli radio wifi on
        notify "WiFi" "Activado"
    fi
}

current_connection() {
    nmcli -t -f NAME,TYPE connection show --active | grep wireless | cut -d: -f1
}

scan_and_list() {
    nmcli device wifi rescan 2>/dev/null

    local current
    current=$(current_connection)

    nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | \
        grep -v '^--' | \
        grep -v '^$' | \
        sort -t: -k2 -rn | \
        awk -F: -v cur="$current" '!seen[$1]++ {
            icon = ""
            if ($2 >= 75) icon = "󰤨"
            else if ($2 >= 50) icon = "󰤥"
            else if ($2 >= 25) icon = "󰤢"
            else icon = "󰤟"

            lock = ($3 != "" && $3 != "--") ? " 󰌾" : ""
            mark = ($1 == cur) ? " [conectado]" : ""
            if ($1 != "") printf "%s %s%s%s  (%s%%)\n", icon, $1, lock, mark, $2
        }'
}

connect_to() {
    local ssid="$1"

    if nmcli -t -f NAME connection show | grep -qx "$ssid"; then
        nmcli connection up "$ssid" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            notify "Conectado" "$ssid"
        else
            notify "Error" "No se pudo conectar a $ssid"
        fi
        return
    fi

    local security
    security=$(nmcli -t -f SSID,SECURITY device wifi list | grep "^${ssid}:" | head -1 | cut -d: -f2)

    if [[ -n "$security" && "$security" != "--" ]]; then
        local pass
        pass=$(rofi -dmenu -password -p "Contraseña" -theme "$THEME" \
            -theme-str 'entry { placeholder: "Contraseña para '"$ssid"'..."; }')
        [[ -z "$pass" ]] && return
        # Pass password via temp NM config file to avoid visibility in ps
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

main_menu() {
    if [[ "$(get_status)" != "enabled" ]]; then
        local choice
        choice=$(echo "󰤮 Activar WiFi" | $ROFI -p "WiFi")
        [[ "$choice" == *"Activar"* ]] && toggle_wifi
        return
    fi

    local current
    current=$(current_connection)

    local header="WiFi"
    [[ -n "$current" ]] && header="$current"

    local options=""
    if [[ -n "$current" ]]; then
        options="󰤭 Desconectar ($current)\n"
    fi
    options+="󰤮 Desactivar WiFi\n"
    options+="󰑓 Escanear redes\n"
    options+="$(scan_and_list)"

    local choice
    choice=$(echo -e "$options" | $ROFI -p "$header")
    [[ -z "$choice" ]] && return

    case "$choice" in
        *"Desconectar"*)
            nmcli connection down "$current" 2>/dev/null
            notify "Desconectado" "$current"
            ;;
        *"Desactivar"*)
            toggle_wifi
            ;;
        *"Escanear"*)
            nmcli device wifi rescan 2>/dev/null
            sleep 2
            main_menu
            ;;
        *)
            local ssid
            ssid=$(echo "$choice" | sed 's/^[^ ]* //;s/ 󰌾//;s/ \[conectado\]//;s/  (.*//')
            [[ -n "$ssid" ]] && connect_to "$ssid"
            ;;
    esac
}

main_menu
