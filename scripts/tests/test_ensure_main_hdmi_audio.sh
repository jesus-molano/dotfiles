#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-desktop/.local/bin/ensure-main-hdmi-audio"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"

cat >"$test_root/bin/pactl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
"list short sinks")
	if [[ -s "$TEST_STATE" ]]; then
		profile=$(<"$TEST_STATE")
		suffix=${profile#output:}
		printf '42\talsa_output.pci-0000_07_00.1.%s\tPipeWire\ts32le 2ch 48000Hz\tIDLE\n' "$suffix"
	fi
	;;
"list short sink-inputs")
	printf '7\t99\t6\tPipeWire\tfloat32le 2ch 48000Hz\n'
	;;
set-card-profile*)
	printf '%s' "$3" >"$TEST_STATE"
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

chmod +x "$test_root/bin/pactl"

PATH="$test_root/bin:$PATH" TEST_STATE="$test_root/state" TEST_LOG="$test_root/log" \
	"$helper"

expected=$'profile=output:hdmi-stereo-extra1\ndefault=alsa_output.pci-0000_07_00.1.hdmi-stereo-extra1\nmove=7:alsa_output.pci-0000_07_00.1.hdmi-stereo-extra1'
actual=$(<"$test_root/log")

[[ "$actual" == "$expected" ]] || {
	printf 'FAIL: ruta HDMI incorrecta\nEsperada:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
	exit 1
}

printf '%s\n' 'PASS: el audio desktop usa el HDMI derecho confirmado'
