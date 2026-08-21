#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-desktop/.local/bin/cycle-desktop-audio-output"}
readonly audio_config="$repo_root/hypr-desktop/.config/noctalia/desktop-audio.toml"
readonly user_binds="$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"

cat >"$test_root/bin/pactl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
"get-default-sink")
	printf '%s\n' "$TEST_CURRENT_SINK"
	;;
"list short sinks")
	printf '%b' "$TEST_SINKS"
	;;
"list sinks")
	printf 'Sink #43\n\tName: %s\n\tDescription: HS70 BLUETOOTH Headset\n' "$TEST_EXTRA_SINK"
	;;
"list short sink-inputs")
	printf '7\t99\t6\tPipeWire\tfloat32le 2ch 48000Hz\n'
	;;
set-card-profile*)
	printf 'profile=%s:%s\n' "$2" "$3" >>"$TEST_LOG"
	;;
set-default-sink*)
	printf 'default=%s\n' "$2" >>"$TEST_LOG"
	;;
move-sink-input*)
	printf 'move=%s:%s\n' "$2" "$3" >>"$TEST_LOG"
	;;
*)
	printf 'pactl inesperado: %s\n' "$*" >&2
	exit 2
	;;
esac
EOF

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'noctalia=%s\n' "$*" >>"$TEST_LOG"
EOF

chmod +x "$test_root/bin/pactl" "$test_root/bin/noctalia"

run_case() {
	local name=$1
	local current_sink=$2
	local expected=$3
	local log="$test_root/$name.log"
	: >"$log"

	PATH="$test_root/bin:$PATH" \
		TEST_CURRENT_SINK="$current_sink" \
		TEST_SINKS="$TEST_ALL_SINKS" \
		TEST_EXTRA_SINK="$bluetooth_sink" \
		TEST_LOG="$log" \
		"$helper"

	local actual
	actual=$(<"$log")
	[[ "$actual" == "$expected" ]] || {
		printf 'FAIL: caso %s\nEsperada:\n%s\nActual:\n%s\n' \
			"$name" "$expected" "$actual" >&2
		exit 1
	}
}

readonly base_sink='alsa_output.pci-0000_07_00.1.hdmi-stereo'
readonly right_sink='alsa_output.pci-0000_07_00.1.hdmi-stereo-extra1'
readonly bluetooth_sink='bluez_output.11_22_33_44_55_66.1'
readonly TEST_ALL_SINKS="41\t${base_sink}\tPipeWire\ts32le 2ch 48000Hz\tIDLE\n42\t${right_sink}\tPipeWire\ts32le 2ch 48000Hz\tIDLE\n43\t${bluetooth_sink}\tPipeWire\ts16le 2ch 48000Hz\tRUNNING\n"

run_case base_to_right "$base_sink" \
	"$(printf 'profile=alsa_card.pci-0000_07_00.1:output:hdmi-stereo-extra1\ndefault=%s\nmove=7:%s\nnoctalia=msg notification-show Audio -- HDMI 2 (monitor derecho) · 2/3' "$right_sink" "$right_sink")"

run_case right_to_bluetooth "$right_sink" \
	"$(printf 'default=%s\nmove=7:%s\nnoctalia=msg notification-show Audio -- HS70 BLUETOOTH Headset · 3/3' "$bluetooth_sink" "$bluetooth_sink")"

run_case bluetooth_to_base "$bluetooth_sink" \
	"$(printf 'profile=alsa_card.pci-0000_07_00.1:output:hdmi-stereo\ndefault=%s\nmove=7:%s\nnoctalia=msg notification-show Audio -- HDMI · 1/3' "$base_sink" "$base_sink")"

grep -Fq 'middle = "exec cycle-desktop-audio-output"' "$audio_config"
grep -Fq 'bind(hyper .. " + H", hl.dsp.exec_cmd("cycle-desktop-audio-output")' "$user_binds"

printf '%s\n' 'PASS: Hyper+H y Noctalia recorren todas las salidas disponibles'
