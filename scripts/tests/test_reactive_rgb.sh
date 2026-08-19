#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-desktop/.local/bin/reactive-rgb"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/config/reactive-rgb" "$test_root/hwmon/hwmon0"
printf '%s\n' k10temp >"$test_root/hwmon/hwmon0/name"
printf '%s\n' 40000 >"$test_root/hwmon/hwmon0/temp1_input"
printf '%s\n' '#!/usr/bin/env bash' \
	'if [[ "$*" == *"--list-devices"* ]]; then [[ -z "${TEST_LIST_LOG:-}" ]] || printf "list\n" >>"$TEST_LIST_LOG"; printf "%s\n" "0: Kingston FURY" "1: ASUS TUF GAMING B550-PLUS (WI-FI)" "  Type: Motherboard" "2: NVIDIA GeForce RTX 3060 Ti" "3: NZXT Smart Device V2"; elif [[ "${TEST_OPENRGB_FAIL:-0}" == 1 ]]; then exit 1; else printf "openrgb:%s\n" "$*" >>"$TEST_LOG"; fi' \
	>"$test_root/bin/openrgb"
printf '%s\n' '#!/usr/bin/env bash' \
	'if [[ "${TEST_GPU_HANG:-0}" == 1 ]]; then sleep 2; else printf "%s\n" "${TEST_GPU_TEMP:-85}"; fi' \
	>"$test_root/bin/nvidia-smi"
chmod +x "$test_root/bin/"*
printf '%s\n' \
	'REACTIVE_RGB_ENABLED=1' \
	'REACTIVE_RGB_AMBIENT_COLOR=123ABC' \
	'REACTIVE_RGB_OPENRGB_DEVICE=ASUS TUF GAMING B550-PLUS (WI-FI)' \
	'REACTIVE_RGB_NZXT_DEVICE=NZXT Smart Device V2' \
	'REACTIVE_RGB_STATIC_COLOR=FFFFFF' \
	'REACTIVE_RGB_OPENRGB_ZONE=1' \
	'REACTIVE_RGB_OPENRGB_ZONE_SIZE=60' \
	'REACTIVE_RGB_CPU_LED_COUNT=12' \
	'REACTIVE_RGB_CPU_GREEN_THRESHOLD=50' \
	'REACTIVE_RGB_CPU_ORANGE_THRESHOLD=70' \
	'REACTIVE_RGB_CPU_RED_THRESHOLD=85' \
	'REACTIVE_RGB_GPU_GREEN_THRESHOLD=50' \
	'REACTIVE_RGB_GPU_ORANGE_THRESHOLD=70' \
	'REACTIVE_RGB_GPU_RED_THRESHOLD=83' \
	'REACTIVE_RGB_DEBOUNCE=1' \
	'REACTIVE_RGB_INTERVAL=1' \
	>"$test_root/config/reactive-rgb/config.conf"
: >"$test_root/log"
: >"$test_root/list-log"
env_base=(PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" REACTIVE_RGB_RUNTIME_DIR="$test_root/runtime" REACTIVE_RGB_HWMON_ROOT="$test_root/hwmon" REACTIVE_RGB_ALLOW_ROOT_FOR_TESTS=1 TEST_LOG="$test_root/log" TEST_LIST_LOG="$test_root/list-log")

color_list() {
	local cpu=$1 gpu=$2 output='' led
	for ((led = 1; led <= 12; led++)); do output+="${output:+,}$cpu"; done
	for ((led = 13; led <= 60; led++)); do output+=",$gpu"; done
	printf '%s\n' "$output"
}

assert_direct_write() {
	local cpu=$1 gpu=$2 expected
	expected=$(color_list "$cpu" "$gpu")
	grep -Fqx "openrgb:--noautoconnect --device ASUS TUF GAMING B550-PLUS (WI-FI) --zone 0 --mode direct --color FFFFFF --device NZXT Smart Device V2 --zone 0 --mode direct --color FFFFFF --device NZXT Smart Device V2 --zone 1 --mode direct --color FFFFFF --device ASUS TUF GAMING B550-PLUS (WI-FI) --zone 1 --size 60 --mode direct --color $expected" "$test_root/log"
}

assert_thermal_colors() {
	local cpu_temperature=$1 gpu_temperature=$2 cpu_color=$3 gpu_color=$4 plan
	printf '%s000\n' "$cpu_temperature" >"$test_root/hwmon/hwmon0/temp1_input"
	rm -f "$test_root/runtime/cpu-band" "$test_root/runtime/gpu-band"
	plan=$(env "${env_base[@]}" TEST_GPU_TEMP="$gpu_temperature" "$helper" dry-run --mode thermal)
	grep -Fxq "cpu_color=$cpu_color" <<<"$plan"
	grep -Fxq "gpu_color=$gpu_color" <<<"$plan"
}

status=$(env "${env_base[@]}" "$helper" detect)
grep -Fxq 'opt_in=1' <<<"$status"
grep -Fxq 'openrgb_target=1:ASUS TUF GAMING B550-PLUS (WI-FI)' <<<"$status"
grep -Fxq 'openrgb_zone=1' <<<"$status"
grep -Fxq 'openrgb_zone_size=60' <<<"$status"
grep -Fxq 'cpu_led_count=12' <<<"$status"
grep -Fxq 'openrgb_static_nzxt=3:NZXT Smart Device V2' <<<"$status"
grep -Fxq 'openrgb_static_color=FFFFFF' <<<"$status"
plan=$(env "${env_base[@]}" "$helper" dry-run --mode ambient)
grep -Fxq 'cpu_color=123ABC' <<<"$plan"
grep -Fxq 'gpu_color=123ABC' <<<"$plan"
[[ ! -s "$test_root/log" ]] || { printf '%s\n' 'FAIL: dry-run escribió hardware' >&2; exit 1; }

# CPU fría: LEDs 1-12 azules. GPU crítica: LEDs 13-60 rojos.
env "${env_base[@]}" TEST_GPU_TEMP=85 "$helper" run-once --mode thermal >/dev/null
assert_direct_write 2080FF FF0000
[[ $(<"$test_root/runtime/cpu-band") == cool ]]
[[ $(<"$test_root/runtime/gpu-band") == critical ]]
[[ $(<"$test_root/runtime/cpu-color") == 2080FF ]]
[[ $(<"$test_root/runtime/gpu-color") == FF0000 ]]
if grep -qiE 'kingston|nvidia|liquidctl|pwm|fan' "$test_root/log"; then
	printf '%s\n' 'FAIL: intentó controlar RAM, GPU, liquidctl, PWM o ventiladores.' >&2
	exit 1
fi

# Los umbrales son independientes: CPU 65 es verde y GPU 70 es naranja.
printf '%s\n' 65000 >"$test_root/hwmon/hwmon0/temp1_input"
env "${env_base[@]}" TEST_GPU_TEMP=70 "$helper" run-once --mode thermal >/dev/null
assert_direct_write 20D070 FF4000

# Histéresis por componente: la CPU queda verde a 49 y la GPU naranja a 69.
printf '%s\n' 49000 >"$test_root/hwmon/hwmon0/temp1_input"
env "${env_base[@]}" TEST_GPU_TEMP=69 "$helper" run-once --mode thermal >/dev/null
assert_direct_write 20D070 FF4000
[[ $(<"$test_root/runtime/cpu-band") == normal ]]
[[ $(<"$test_root/runtime/gpu-band") == warm ]]

# Límites exactos, sin estado previo para no mezclar la histéresis.
assert_thermal_colors 49 49 2080FF 2080FF
assert_thermal_colors 50 50 20D070 20D070
assert_thermal_colors 69 69 20D070 20D070
assert_thermal_colors 70 70 FF4000 FF4000
assert_thermal_colors 84 82 FF4000 FF4000
assert_thermal_colors 85 82 FF0000 FF4000
assert_thermal_colors 84 83 FF4000 FF0000
set +e
timeout 1s env "${env_base[@]}" REACTIVE_RGB_NVIDIA_TIMEOUT=0.05 TEST_GPU_HANG=1 \
	"$helper" dry-run --mode thermal >/dev/null 2>&1
gpu_timeout_code=$?
set -e
[[ $gpu_timeout_code -eq 1 ]] || { printf '%s\n' 'FAIL: el térmico debe exigir temperatura GPU.' >&2; exit 1; }

# La configuración rechaza límites fuera de orden antes de tocar hardware.
cp "$test_root/config/reactive-rgb/config.conf" "$test_root/config/reactive-rgb/config.valid"
printf '%s\n' \
	'REACTIVE_RGB_CPU_GREEN_THRESHOLD=70' \
	'REACTIVE_RGB_CPU_ORANGE_THRESHOLD=60' \
	'REACTIVE_RGB_CPU_RED_THRESHOLD=85' \
	>"$test_root/config/reactive-rgb/config.conf"
set +e
invalid_thresholds=$(env "${env_base[@]}" "$helper" dry-run --mode ambient 2>&1)
invalid_thresholds_code=$?
set -e

if [[ $invalid_thresholds_code -ne 2 ]] || ! grep -q 'Umbrales RGB inválidos' <<<"$invalid_thresholds"; then
	printf '%s\n' 'FAIL: aceptó umbrales RGB fuera de orden.' >&2
	exit 1
fi
mv "$test_root/config/reactive-rgb/config.valid" "$test_root/config/reactive-rgb/config.conf"

# `run` conserva lock, salud y reaplicación; el modo ambiente da el mismo color
# a los 60 LEDs, pero sigue sin seleccionar otro dispositivo o controlador.
: >"$test_root/log"
: >"$test_root/list-log"
env "${env_base[@]}" "$helper" run --mode ambient >/dev/null 2>&1 & healthy_pid=$!
sleep 0.2
assert_direct_write 123ABC 123ABC
health=$(env "${env_base[@]}" "$helper" health)
grep -Fxq 'health_status=ok' <<<"$health"
grep -Fxq 'health_fresh=1' <<<"$health"
set +e
env "${env_base[@]}" "$helper" run-once --mode ambient >/dev/null 2>&1
lock_code=$?
set -e
[[ $lock_code -eq 75 ]] || { printf '%s\n' 'FAIL: una segunda instancia accedió al hardware.' >&2; exit 1; }
kill -TERM "$healthy_pid"
wait "$healthy_pid"
health=$(env "${env_base[@]}" "$helper" health)
grep -Fxq 'health_status=ok' <<<"$health"
grep -Fxq 'health_fresh=0' <<<"$health"

# Un fallo de OpenRGB no queda saludable. La enumeración se hace una vez por run.
rm -f "$test_root/runtime/cpu-color" "$test_root/runtime/gpu-color"
: >"$test_root/list-log"
set +e
env "${env_base[@]}" TEST_OPENRGB_FAIL=1 "$helper" run --mode ambient >/dev/null 2>&1
code=$?
set -e
[[ $code -eq 1 ]] || { printf '%s\n' 'FAIL: run no terminó tras tres fallos consecutivos' >&2; exit 1; }
health=$(env "${env_base[@]}" "$helper" health)
grep -Fxq 'health_status=error' <<<"$health"
grep -Fxq 'health_consecutive_failures=3' <<<"$health"
grep -Fxq 'health_fresh=0' <<<"$health"
[[ $(grep -Fxc list "$test_root/list-log") -eq 1 ]] || { printf '%s\n' 'FAIL: OpenRGB se enumeró más de una vez durante run' >&2; exit 1; }

rm -f "$test_root/config/reactive-rgb/config.conf"
set +e
disabled=$(env "${env_base[@]}" "$helper" run-once --mode ambient 2>&1)
code=$?
set -e
[[ $code -eq 3 ]] && grep -q 'desactivado' <<<"$disabled"
disabled_run=$(timeout 1s env "${env_base[@]}" "$helper" run --mode ambient)
grep -q 'termina sin error' <<<"$disabled_run"
printf '%s\n' 'PASS: Reactive RGB separa CPU/GPU, fija frontal/superior en blanco y usa solo OpenRGB'
