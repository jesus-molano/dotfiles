#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/audio/.local/bin/audio-route-manager"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"

cat >"$test_root/bin/pactl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
"list short sinks") cat "$TEST_SINKS" ;;
"list short sink-inputs") printf '7\t99\t6\tPipeWire\tfloat32le 2ch 48000Hz\n' ;;
"get-default-sink") [[ -s "$TEST_DEFAULT" ]] && cat "$TEST_DEFAULT" ;;
"-f json list sinks") cat "$TEST_SINKS_JSON" ;;
"subscribe")
	while IFS= read -r action; do
		case "$action" in
		add-preferred)
			printf '81\t%s1\tPipeWire\ts16le 2ch 48000Hz\tIDLE\n' "$DOTFILES_AUDIO_PREFERRED_SINK_PREFIX" >>"$TEST_SINKS"
			;;
		remove-preferred)
			awk -v prefix="$DOTFILES_AUDIO_PREFERRED_SINK_PREFIX" 'index($2, prefix) != 1' "$TEST_SINKS" >"$TEST_SINKS.next"
			mv -- "$TEST_SINKS.next" "$TEST_SINKS"
			;;
		esac
		printf "Event 'change' on sink #1\n"
		sleep 0.2
	done <"$TEST_ACTIONS"
	;;
set-card-profile*)
	printf 'profile=%s\n' "$3" >>"$TEST_LOG"
	if [[ ${TEST_PROFILE_CREATES_FALLBACK:-0} == 1 ]] && ! grep -Fq "$DOTFILES_AUDIO_DEFAULT_SINK" "$TEST_SINKS"; then
		printf '42\t%s\tPipeWire\ts32le 2ch 48000Hz\tIDLE\n' "$DOTFILES_AUDIO_DEFAULT_SINK" >>"$TEST_SINKS"
	fi
	;;
set-default-sink*)
	printf '%s\n' "$2" >"$TEST_DEFAULT"
	printf 'default=%s\n' "$2" >>"$TEST_LOG"
	;;
move-sink-input*) printf 'move=%s:%s\n' "$2" "$3" >>"$TEST_LOG" ;;
*) printf 'pactl inesperado: %s\n' "$*" >&2; exit 2 ;;
esac
EOF

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$test_root/bin/pactl" "$test_root/bin/noctalia"

export PATH="$test_root/bin:$PATH"
export DOTFILES_AUDIO_CARD='alsa_card.pci-0000_07_00.1'
export DOTFILES_AUDIO_DEFAULT_PROFILE='output:hdmi-stereo-extra1'
export DOTFILES_AUDIO_DEFAULT_SINK='alsa_output.pci-0000_07_00.1.hdmi-stereo-extra1'
export DOTFILES_AUDIO_PREFERRED_SINK_PREFIX='bluez_output.20_06_10_13_61_73.'
export AUDIO_ROUTE_RETRIES=1
export TEST_SINKS="$test_root/sinks"
export TEST_SINKS_JSON="$test_root/sinks.json"
export TEST_DEFAULT="$test_root/default"
export TEST_ACTIONS="$test_root/actions"
export TEST_LOG="$test_root/log"

fallback_line=$'42\talsa_output.pci-0000_07_00.1.hdmi-stereo-extra1\tPipeWire\ts32le 2ch 48000Hz\tIDLE'
preferred_line=$'81\tbluez_output.20_06_10_13_61_73.1\tPipeWire\ts16le 2ch 48000Hz\tIDLE'
printf '%s\n' "$fallback_line" "$preferred_line" >"$TEST_SINKS"
printf '[]\n' >"$TEST_SINKS_JSON"
: >"$TEST_ACTIONS"
: >"$TEST_LOG"
: >"$TEST_DEFAULT"

"$helper" --once
grep -Fxq 'default=bluez_output.20_06_10_13_61_73.1' "$TEST_LOG"
grep -Fxq 'move=7:bluez_output.20_06_10_13_61_73.1' "$TEST_LOG"

printf '%s\n' "$fallback_line" >"$TEST_SINKS"
printf '%s\n' add-preferred unrelated remove-preferred >"$TEST_ACTIONS"
: >"$TEST_LOG"
: >"$TEST_DEFAULT"

"$helper" --watch
[[ $(grep -Fc 'default=bluez_output.20_06_10_13_61_73.1' "$TEST_LOG") == 1 ]]
[[ $(grep -Fc 'default=alsa_output.pci-0000_07_00.1.hdmi-stereo-extra1' "$TEST_LOG") == 2 ]]

: >"$TEST_SINKS"
: >"$TEST_LOG"
: >"$TEST_DEFAULT"
: >"$TEST_ACTIONS"
TEST_PROFILE_CREATES_FALLBACK=1 "$helper" --once
grep -Fxq 'profile=output:hdmi-stereo-extra1' "$TEST_LOG"
grep -Fxq 'default=alsa_output.pci-0000_07_00.1.hdmi-stereo-extra1' "$TEST_LOG"

cat >"$TEST_SINKS" <<'EOF'
10	alsa_output.pci-0000_09_00.4.iec958-stereo	PipeWire	s32le 2ch 48000Hz	SUSPENDED
11	alsa_output.usb-real.analog-stereo	PipeWire	s32le 2ch 48000Hz	IDLE
EOF
cat >"$TEST_SINKS_JSON" <<'EOF'
[
  {"name":"alsa_output.pci-0000_09_00.4.iec958-stereo","ports":[{"availability":"availability unknown","priority":0}]},
  {"name":"alsa_output.usb-real.analog-stereo","ports":[{"availability":"available","priority":9000}]},
  {"name":"auto_null","ports":[{"availability":"available","priority":9999}]}
]
EOF
: >"$TEST_LOG"
: >"$TEST_DEFAULT"
: >"$TEST_ACTIONS"

"$helper" --once
grep -Fxq 'default=alsa_output.usb-real.analog-stereo' "$TEST_LOG"
if grep -Fq 'default=alsa_output.pci-0000_09_00.4.iec958-stereo' "$TEST_LOG"; then
	exit 1
fi
if grep -Fq 'default=auto_null' "$TEST_LOG"; then
	exit 1
fi

printf '%s\n' 'PASS: el audio sigue presencia Bluetooth, conserva cambios manuales y usa fallback físico'
