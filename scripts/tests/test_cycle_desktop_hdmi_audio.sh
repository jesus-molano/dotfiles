#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-desktop/.local/bin/cycle-desktop-hdmi-audio"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"

cat >"$test_root/bin/pactl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
"get-default-sink")
	printf '%s\n' "alsa_output.pci-0000_07_00.1.${TEST_CURRENT_PROFILE#output:}"
	;;
"list short sinks")
	profile=$(<"$TEST_SELECTED_FILE")
	printf '42\talsa_output.pci-0000_07_00.1.%s\tPipeWire\ts32le 2ch 48000Hz\tIDLE\n' "${profile#output:}"
	;;
"list short sink-inputs")
	printf '7\t99\t6\tPipeWire\tfloat32le 2ch 48000Hz\n'
	;;
set-card-profile*)
	printf '%s' "$3" >"$TEST_SELECTED_FILE"
	printf 'profile=%s\n' "$3" >>"$TEST_LOG"
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
	local current_profile=$1
	local expected_profile=$2
	local expected_label=$3
	local log=$test_root/log
	local selected=$test_root/selected
	: >"$log"
	printf '%s' "$current_profile" >"$selected"

	PATH="$test_root/bin:$PATH" \
		TEST_CURRENT_PROFILE="$current_profile" \
		TEST_SELECTED_FILE="$selected" \
		TEST_LOG="$log" \
		"$helper"

	local expected_sink="alsa_output.pci-0000_07_00.1.${expected_profile#output:}"
	local expected
	expected=$(printf 'profile=%s\ndefault=%s\nmove=7:%s\nnoctalia=msg notification-show Audio HDMI -- %s' \
		"$expected_profile" "$expected_sink" "$expected_sink" "$expected_label")
	local actual
	actual=$(<"$log")

	[[ "$actual" == "$expected" ]] || {
		printf 'FAIL: alternancia HDMI incorrecta\nEsperada:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
		exit 1
	}
}

run_case 'output:hdmi-stereo-extra1' 'output:hdmi-stereo' 'Salida HDMI'
run_case 'output:hdmi-stereo' 'output:hdmi-stereo-extra1' 'Salida HDMI 2 (monitor derecho)'

printf '%s\n' 'PASS: el control de Noctalia alterna las dos salidas HDMI'
