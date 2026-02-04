#!/bin/bash
set -uo pipefail

# Bluetooth management menu via rofi + bluetoothctl

THEME="$HOME/.config/waybar/scripts/rofi-theme.rasi"
ROFI="rofi -dmenu -i -theme $THEME"

notify() { notify-send -a "Bluetooth" "$1" "$2"; }

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
    bluetoothctl show | grep -q "Powered: yes" && echo "on" || echo "off"
}

toggle_power() {
    if [[ "$(bt_power_status)" == "on" ]]; then
        bluetoothctl power off >/dev/null 2>&1
        notify "Bluetooth" "Desactivado"
    else
        bluetoothctl power on >/dev/null 2>&1
        notify "Bluetooth" "Activado"
    fi
}

get_paired_devices() {
    bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do
        local connected=""
        bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" && connected=" [conectado]"
        echo "$mac $name$connected"
    done
}

get_available_devices() {
    bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
        if ! bluetoothctl devices Paired 2>/dev/null | grep -q "$mac"; then
            echo "$mac $name"
        fi
    done
}

device_menu() {
    local mac="$1"
    local name="$2"
    local is_connected=""
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" && is_connected="yes"

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
            if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
                notify "Conectado" "$name"
            else
                notify "Error" "No se pudo conectar a $name"
            fi
            ;;
        *"Desconectar"*)
            bluetoothctl disconnect "$mac" >/dev/null 2>&1
            notify "Desconectado" "$name"
            ;;
        *"Olvidar"*)
            bluetoothctl remove "$mac" >/dev/null 2>&1
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

    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
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
            mac=$(bluetoothctl devices Paired 2>/dev/null | grep "$dev_name" | awk '{print $2}')
            [[ -n "$mac" ]] && device_menu "$mac" "$dev_name"
            ;;
    esac
}

main_menu
