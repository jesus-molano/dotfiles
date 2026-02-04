#!/usr/bin/env bash
# Hardware monitor for Waybar custom modules
# Usage: hw-monitor.sh {cpu-temp|gpu-temp|fan-speed}
# Outputs JSON: {"text": "...", "tooltip": "...", "class": "..."}

CACHE_FILE="/tmp/waybar-hw-cache"
CACHE_TTL=4

refresh_cache() {
    local now
    now=$(date +%s)
    if [[ -f "$CACHE_FILE" ]]; then
        local mtime
        mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        if (( now - mtime < CACHE_TTL )); then
            return
        fi
    fi

    # Collect sensor data with chip filters to avoid hangs
    local gpu_out
    gpu_out="$(nvidia-smi --query-gpu=temperature.gpu,fan.speed,power.draw,utilization.gpu --format=csv,noheader,nounits 2>/dev/null)"

    # Parse CPU temp (k10temp Tctl) — filtered by chip
    local cpu_temp
    cpu_temp="$(sensors -u k10temp-pci-00c3 2>/dev/null | awk '/temp1_input/ {printf "%.0f", $2}')"

    # Parse NZXT fan speeds — filtered by chip
    local fan2_rpm fan3_rpm
    fan2_rpm="$(sensors nzxtsmart2-hid-3-1 2>/dev/null | awk '/^FAN 2:/ {print $3}')"
    fan3_rpm="$(sensors nzxtsmart2-hid-3-1 2>/dev/null | awk '/^FAN 3:/ {print $3}')"

    # Parse GPU data
    local gpu_temp gpu_fan gpu_power gpu_util
    if [[ -n "$gpu_out" ]]; then
        IFS=', ' read -r gpu_temp gpu_fan gpu_power gpu_util <<< "$gpu_out"
    fi

    cat > "$CACHE_FILE" <<EOF
CPU_TEMP=${cpu_temp:-0}
FAN2_RPM=${fan2_rpm:-0}
FAN3_RPM=${fan3_rpm:-0}
GPU_TEMP=${gpu_temp:-0}
GPU_FAN=${gpu_fan:-0}
GPU_POWER=${gpu_power:-0}
GPU_UTIL=${gpu_util:-0}
EOF
}

refresh_cache
source "$CACHE_FILE"

case "$1" in
    cpu-temp)
        class="normal"
        (( CPU_TEMP >= 80 )) && class="critical"
        (( CPU_TEMP >= 65 && CPU_TEMP < 80 )) && class="warning"
        printf '{"text": "%s°C", "tooltip": "CPU (k10temp Tctl): %s°C\\nFAN 2: %s RPM\\nFAN 3: %s RPM", "class": "%s"}\n' \
            "$CPU_TEMP" "$CPU_TEMP" "$FAN2_RPM" "$FAN3_RPM" "$class"
        ;;
    gpu-temp)
        class="normal"
        (( GPU_TEMP >= 83 )) && class="critical"
        (( GPU_TEMP >= 70 && GPU_TEMP < 83 )) && class="warning"
        printf '{"text": "%s°C", "tooltip": "GPU: %s°C\\nFan: %s%%\\nPower: %s W\\nUsage: %s%%", "class": "%s"}\n' \
            "$GPU_TEMP" "$GPU_TEMP" "$GPU_FAN" "$GPU_POWER" "$GPU_UTIL" "$class"
        ;;
    fan-speed)
        avg_rpm=$(( (FAN2_RPM + FAN3_RPM) / 2 ))
        printf '{"text": "%s", "tooltip": "NZXT Smart Device V2\\nFAN 2: %s RPM\\nFAN 3: %s RPM", "class": "normal"}\n' \
            "$avg_rpm" "$FAN2_RPM" "$FAN3_RPM"
        ;;
    *)
        echo '{"text": "?", "tooltip": "Unknown argument: '"$1"'", "class": "normal"}'
        ;;
esac
