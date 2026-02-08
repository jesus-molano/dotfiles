#!/usr/bin/env bash
set -euo pipefail
# Hardware monitor for Waybar custom modules
# Usage: hw-monitor.sh {cpu-temp|gpu-temp|fan-speed}
# Outputs JSON: {"text": "...", "tooltip": "...", "class": "..."}

CACHE_FILE="/tmp/waybar-hw-cache"
CACHE_TTL=4

# Discover hwmon sysfs paths once at startup
K10TEMP_PATH=""
NZXT_FAN2_PATH=""
NZXT_FAN3_PATH=""

init_hwmon_paths() {
    local name dir
    for f in /sys/class/hwmon/hwmon*/name; do
        dir="$(dirname "$f")"
        name="$(cat "$f" 2>/dev/null)"
        case "$name" in
            k10temp)
                K10TEMP_PATH="$dir/temp1_input"
                ;;
            nzxtsmart*)
                NZXT_FAN2_PATH="$dir/fan2_input"
                NZXT_FAN3_PATH="$dir/fan3_input"
                ;;
        esac
    done
}

init_hwmon_paths

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

    # GPU data (nvidia-smi is already a single call)
    local gpu_out
    gpu_out="$(timeout 2 nvidia-smi --query-gpu=temperature.gpu,fan.speed,power.draw,utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true)"

    # CPU temp from sysfs (millidegrees → degrees)
    local cpu_temp=0
    if [[ -n "$K10TEMP_PATH" && -r "$K10TEMP_PATH" ]]; then
        cpu_temp=$(( $(cat "$K10TEMP_PATH") / 1000 ))
    fi

    # NZXT fan speeds from sysfs (already in RPM)
    local fan2_rpm=0 fan3_rpm=0
    [[ -n "$NZXT_FAN2_PATH" && -r "$NZXT_FAN2_PATH" ]] && fan2_rpm=$(cat "$NZXT_FAN2_PATH")
    [[ -n "$NZXT_FAN3_PATH" && -r "$NZXT_FAN3_PATH" ]] && fan3_rpm=$(cat "$NZXT_FAN3_PATH")

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
if [[ ! -f "$CACHE_FILE" ]]; then
    refresh_cache
fi
source "$CACHE_FILE"

case "$1" in
    cpu-temp)
        class="normal"
        (( CPU_TEMP >= 80 )) && class="critical" || true
        (( CPU_TEMP >= 65 && CPU_TEMP < 80 )) && class="warning" || true
        printf '{"text": "%s°C", "tooltip": "CPU (k10temp Tctl): %s°C\\nFAN 2: %s RPM\\nFAN 3: %s RPM", "class": "%s"}\n' \
            "$CPU_TEMP" "$CPU_TEMP" "$FAN2_RPM" "$FAN3_RPM" "$class"
        ;;
    gpu-temp)
        class="normal"
        (( GPU_TEMP >= 83 )) && class="critical" || true
        (( GPU_TEMP >= 70 && GPU_TEMP < 83 )) && class="warning" || true
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
