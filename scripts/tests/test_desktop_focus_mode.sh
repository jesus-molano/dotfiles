#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/desktop-focus-mode"}
test_root=$(mktemp -d)
cleanup() {
	local file pid
	while IFS= read -r file; do
		[[ -s "$file" ]] || continue
		pid=$(<"$file")
		[[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null || true
	done < <(find "$test_root" -maxdepth 1 -type f -name '*-recording' 2>/dev/null)
	rm -rf -- "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/bin"

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
"msg notification-dnd-status") printf '%s\n' "$TEST_DND" ;;
"msg status") printf '{"barVisible":%s}\n' "$TEST_BAR_VISIBLE" ;;
"msg notification-dnd-set "*) printf 'dnd:%s\n' "$3" >>"$TEST_LOG" ;;
"msg caffeine-enable")
	printf '%s\n' on >"$TEST_CAFFEINE_FILE"
	printf '%s\n' 'caffeine:on' >>"$TEST_LOG"
	;;
"msg caffeine-disable")
	printf '%s\n' off >"$TEST_CAFFEINE_FILE"
	printf '%s\n' 'caffeine:off' >>"$TEST_LOG"
	;;
"msg power-set "*)
	printf '%s\n' "$3" >"$TEST_POWER_FILE"
	printf 'power:%s\n' "$3" >>"$TEST_LOG"
	;;
"msg bar-hide") printf '%s\n' 'bar:hide' >>"$TEST_LOG" ;;
"msg bar-show") printf '%s\n' 'bar:show' >>"$TEST_LOG" ;;
"msg plugin "*)
	printf 'plugin:%s\n' "${*:3}" >>"$TEST_LOG"
	case "${*:3}" in
	*" start focused")
		sleep 30 &
		printf '%s\n' "$!" >"$TEST_RECORDING_FILE"
		;;
	*" stop")
		if [[ -s "$TEST_RECORDING_FILE" ]]; then
			kill "$(<"$TEST_RECORDING_FILE")" 2>/dev/null || true
			: >"$TEST_RECORDING_FILE"
		fi
		;;
	esac
	;;
*)
	printf 'Noctalia inesperado: %s\n' "$*" >&2
	exit 2
	;;
esac
EOF

cat >"$test_root/bin/systemd-inhibit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == '--list --json=short' ]]
if [[ "$(<"$TEST_CAFFEINE_FILE")" == on ]]; then
	printf '%s\n' '[{"who":"noctalia","why":"Caffeine","what":"idle"}]'
else
	printf '%s\n' '[]'
fi
EOF

cat >"$test_root/bin/powerprofilesctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == get ]]
cat "$TEST_POWER_FILE"
EOF

cat >"$test_root/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -s "$TEST_RECORDING_FILE" ]] || exit 1
pid=$(<"$TEST_RECORDING_FILE")
[[ -r "/proc/$pid/stat" ]] || exit 1
printf '%s\n' "$pid"
EOF

chmod +x "$test_root/bin/noctalia" "$test_root/bin/systemd-inhibit" \
	"$test_root/bin/powerprofilesctl" "$test_root/bin/pgrep"

run_case() {
	local name=$1 action=$2 dnd=$3 bar_visible=$4 caffeine=$5 power=$6 recording=$7 expected=$8
	local log="$test_root/$name.log" recording_file="$test_root/$name-recording"
	: >"$log"
	: >"$recording_file"
	mkdir -p "$test_root/$name-runtime"
	printf '%s\n' "$caffeine" >"$test_root/$name-caffeine"
	printf '%s\n' "$power" >"$test_root/$name-power"
	if [[ "$recording" == true ]]; then
		sleep 30 &
		printf '%s\n' "$!" >"$recording_file"
	fi

	PATH="$test_root/bin:$PATH" \
		XDG_STATE_HOME="$test_root/$name-state" \
		XDG_RUNTIME_DIR="$test_root/$name-runtime" \
		TEST_CAFFEINE_FILE="$test_root/$name-caffeine" TEST_POWER_FILE="$test_root/$name-power" \
		TEST_LOG="$log" TEST_DND="$dnd" TEST_BAR_VISIBLE="$bar_visible" TEST_RECORDING_FILE="$recording_file" \
		"$helper" "$action"
	PATH="$test_root/bin:$PATH" \
		XDG_STATE_HOME="$test_root/$name-state" \
		XDG_RUNTIME_DIR="$test_root/$name-runtime" \
		TEST_CAFFEINE_FILE="$test_root/$name-caffeine" TEST_POWER_FILE="$test_root/$name-power" \
		TEST_LOG="$log" TEST_DND="$dnd" TEST_BAR_VISIBLE="$bar_visible" TEST_RECORDING_FILE="$recording_file" \
		"$helper" off
	if [[ -s "$recording_file" ]]; then
		kill "$(<"$recording_file")" 2>/dev/null || true
	fi

	actual=$(<"$log")
	[[ "$actual" == "$expected" ]] || {
		printf 'FAIL (%s): secuencia inesperada\nEsperada:\n%s\nActual:\n%s\n' \
			"$name" "$expected" "$actual" >&2
		exit 1
	}
	[[ ! -e "$test_root/$name-state/dotfiles/desktop-focus-mode/state" ]] || {
		printf 'FAIL (%s): el estado no se eliminó\n' "$name" >&2
		exit 1
	}
}

run_case focus on off true off balanced false \
	$'caffeine:on\npower:performance\ndnd:on\nbar:hide\nbar:show\ndnd:off\npower:balanced\ncaffeine:off'
run_case demo demo off true off power-saver false \
	$'caffeine:on\npower:performance\ndnd:on\nbar:hide\nplugin:noctalia/screen_recorder:service all start focused\nplugin:noctalia/screen_recorder:service all stop\nbar:show\ndnd:off\npower:power-saver\ncaffeine:off'
run_case preserve demo on false on performance true ''

mkdir -p "$test_root/gaming-runtime/dotfiles-gaming-sessions"
shell_starttime=$(awk '{ print $22 }' "/proc/$$/stat")
printf '%s %s\n' "$$" "$shell_starttime" >"$test_root/gaming-runtime/dotfiles-gaming-sessions/$$"
: >"$test_root/gaming-recording"
: >"$test_root/gaming.log"
printf '%s\n' off >"$test_root/gaming-caffeine"
printf '%s\n' balanced >"$test_root/gaming-power"
set +e
PATH="$test_root/bin:$PATH" XDG_STATE_HOME="$test_root/gaming-state" \
	XDG_RUNTIME_DIR="$test_root/gaming-runtime" TEST_CAFFEINE_FILE="$test_root/gaming-caffeine" \
	TEST_POWER_FILE="$test_root/gaming-power" TEST_LOG="$test_root/gaming.log" \
	TEST_DND=off TEST_BAR_VISIBLE=true TEST_RECORDING_FILE="$test_root/gaming-recording" \
	"$helper" on >/dev/null 2>&1
gaming_status=$?
set -e
[[ $gaming_status -ne 0 && ! -e "$test_root/gaming-state/dotfiles/desktop-focus-mode/state" ]] || {
	printf '%s\n' 'FAIL: modo foco se activó durante una sesión gaming' >&2
	exit 1
}

printf '%s\n' 'PASS: el modo foco restaura DND, barra, cafeína, potencia y grabación propia'
