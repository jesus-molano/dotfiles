#!/bin/bash
set -uo pipefail

# Bluetooth management menu via rofi + bluetoothctl
# NOTE: bluez 5.86+ broke non-interactive bluetoothctl output.
# btctl_cmd() wraps commands in interactive mode; busctl queries D-Bus directly.

THEME="$HOME/.config/waybar/scripts/rofi-theme.rasi"
ROFI="rofi -dmenu -i -theme $THEME"

notify() { notify-send -a "Bluetooth" "$1" "$2"; }

# Strip ANSI escape codes and bluetoothctl prompt noise from interactive output
strip_ansi() {
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' | sed 's/\x1b\[K//g' | sed 's/\r//g'
}

# Run a single bluetoothctl command interactively (bluez 5.86 compat)
btctl_cmd() {
    printf '%s\nquit\n' "$1" | bluetoothctl 2>/dev/null | strip_ansi
}

# Run bluetoothctl commands via FIFO to keep agent alive during the session
# Each argument is a command, optionally prefixed with "sleep:N" to wait N seconds
btctl_session() {
    local fifo
    fifo=$(mktemp -u /tmp/btctl.XXXXX)
    mkfifo "$fifo"
    trap 'rm -f "$fifo"' EXIT
    bluetoothctl < "$fifo" >/dev/null 2>&1 &
    local pid=$!
    exec 3>"$fifo"

    sleep 0.5
    echo "agent NoInputNoOutput" >&3
    sleep 0.3
    echo "default-agent" >&3
    sleep 0.3

    for cmd in "$@"; do
        if [[ "$cmd" == sleep:* ]]; then
            sleep "${cmd#sleep:}"
        else
            echo "$cmd" >&3
            sleep 0.3
        fi
    done

    echo "quit" >&3
    exec 3>&-
    wait $pid 2>/dev/null
    rm -f "$fifo"
}

bt_power_status() {
    busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null \
        | grep -q "b true" && echo "on" || echo "off"
}

toggle_power() {
    if [[ "$(bt_power_status)" == "on" ]]; then
        btctl_cmd "power off" >/dev/null
        notify "Bluetooth" "Desactivado"
    else
        btctl_cmd "power on" >/dev/null
        notify "Bluetooth" "Activado"
    fi
}

get_paired_devices() {
    btctl_cmd "devices Paired" | grep "^Device" | while read -r _ mac name; do
        local connected=""
        btctl_cmd "info $mac" | grep -q "Connected: yes" && connected=" [conectado]"
        echo "$mac $name$connected"
    done
}

get_available_devices() {
    local paired
    paired=$(btctl_cmd "devices Paired" | grep "^Device" | awk '{print $2}')
    btctl_cmd "devices" | grep "^Device" | while read -r _ mac name; do
        echo "$paired" | grep -q "$mac" || echo "$mac $name"
    done
}

device_menu() {
    local mac="$1"
    local name="$2"
    local is_connected=""
    btctl_cmd "info $mac" | grep -q "Connected: yes" && is_connected="yes"

    local options=""
    if [[ "$is_connected" == "yes" ]]; then
        options="󰂲 Desconectar\n󱉝 Olvidar dispositivo"
    else
        options="󰂱 Conectar\n󱉝 Olvidar dispositivo"
    fi

    local choice
    choice=$(echo -e "$options" | $ROFI -p "$name")
    [[ -z "$choice" ]] && return

    case "$choice" in
        *"Conectar"*)
            notify "Conectando..." "$name"
            btctl_session "connect $mac" "sleep:3"
            if btctl_cmd "info $mac" | grep -q "Connected: yes"; then
                notify "Conectado" "$name"
            else
                notify "Error" "No se pudo conectar a $name"
            fi
            ;;
        *"Desconectar"*)
            btctl_cmd "disconnect $mac" >/dev/null
            notify "Desconectado" "$name"
            ;;
        *"Olvidar"*)
            btctl_cmd "remove $mac" >/dev/null
            notify "Eliminado" "$name"
            ;;
    esac
}

new_device_menu() {
    notify "Escaneando..." "Buscando dispositivos cercanos (10s)"

    btctl_session "pairable on" "scan on" "sleep:10" "scan off"

    local devices
    devices=$(get_available_devices)

    if [[ -z "$devices" ]]; then
        notify "Escaneo" "No se encontraron dispositivos nuevos"
        return
    fi

    local display=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local mac name
        mac=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | cut -d' ' -f2-)
        display+="󰂳 $name ($mac)\n"
    done <<< "$devices"

    local choice
    choice=$(echo -e "$display" | sed '/^$/d' | $ROFI -p "Encontrados")
    [[ -z "$choice" ]] && return

    local mac
    mac=$(echo "$choice" | grep -oP '\([0-9A-Fa-f:]+\)' | tr -d '()')
    [[ -z "$mac" ]] && return

    local name
    name=$(echo "$choice" | sed 's/^[^ ]* //;s/ (.*//')

    notify "Emparejando..." "$name"

    btctl_session \
        "pairable on" \
        "trust $mac" \
        "sleep:1" \
        "pair $mac" \
        "sleep:5" \
        "connect $mac" \
        "sleep:3"

    if btctl_cmd "info $mac" | grep -q "Paired: yes"; then
        if btctl_cmd "info $mac" | grep -q "Connected: yes"; then
            notify "Conectado" "$name"
        else
            notify "Emparejado" "$name (conecta manualmente si es necesario)"
        fi
    else
        notify "Error" "No se pudo emparejar con $name"
    fi
}

main_menu() {
    if [[ "$(bt_power_status)" == "off" ]]; then
        local choice
        choice=$(echo "󰂯 Activar Bluetooth" | $ROFI -p "Bluetooth")
        [[ "$choice" == *"Activar"* ]] && toggle_power
        return
    fi

    local paired
    paired=$(get_paired_devices)

    local options="󰂲 Desactivar Bluetooth\n󰑓 Buscar dispositivos nuevos"

    if [[ -n "$paired" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local mac name_status
            mac=$(echo "$line" | awk '{print $1}')
            name_status=$(echo "$line" | cut -d' ' -f2-)
            if echo "$name_status" | grep -q "\[conectado\]"; then
                options+="\n󰂱 $name_status"
            else
                options+="\n󰂳 $name_status"
            fi
        done <<< "$paired"
    fi

    local choice
    choice=$(echo -e "$options" | $ROFI -p "Bluetooth")
    [[ -z "$choice" ]] && return

    case "$choice" in
        *"Desactivar"*)
            toggle_power
            ;;
        *"Buscar"*)
            new_device_menu
            ;;
        *)
            local dev_name
            dev_name=$(echo "$choice" | sed 's/^[^ ]* //;s/ \[conectado\]//')
            local mac
            mac=$(btctl_cmd "devices Paired" | grep "^Device" | grep "$dev_name" | awk '{print $2}')
            [[ -n "$mac" ]] && device_menu "$mac" "$dev_name"
            ;;
    esac
}

main_menu
