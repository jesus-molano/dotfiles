#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly game_run=${1:-"$repo_root/gaming-core/.local/bin/game-run"}
test_root=$(mktemp -d)
a_pid=''
b_pid=''
cleanup() {
	[[ -z "$a_pid" ]] || kill "$a_pid" 2>/dev/null || true
	[[ -z "$b_pid" ]] || kill "$b_pid" 2>/dev/null || true
	wait "$a_pid" "$b_pid" 2>/dev/null || true
	rm -rf -- "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/bin"

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == msg && "${2:-}" == notification-dnd-status ]]; then
	cat -- "$TEST_DND_STATE"
	exit 0
fi
if [[ "${1:-}" == msg && "${2:-}" == notification-dnd-set ]]; then
	if [[ "${TEST_DND_SET_FAIL:-0}" == 1 ]]; then
		exit 1
	fi
	printf '%s\n' "$3" >"$TEST_DND_STATE"
	printf 'dnd:%s\n' "$3" >>"$TEST_LOG"
	exit 0
fi
exit 2
EOF

cat >"$test_root/bin/game-performance" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'performance:start' >>"$TEST_LOG"
"$@"
EOF

cat >"$test_root/bin/test-game" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'game:running' >>"$TEST_LOG"
exit 23
EOF
cat >"$test_root/bin/test-game-wait" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'game:%s:start\n' "$TEST_GAME_ID" >>"$TEST_LOG"
: >"$TEST_GAME_STARTED"
while [[ ! -e "$TEST_GAME_RELEASE" ]]; do sleep 0.02; done
printf 'game:%s:end\n' "$TEST_GAME_ID" >>"$TEST_LOG"
EOF
cat >"$test_root/bin/desktop-focus-mode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
status) printf '%s\n' "${TEST_FOCUS_INITIAL:-off}" ;;
off) printf '%s\n' 'focus:off' >>"$TEST_LOG" ;;
*) exit 2 ;;
esac
EOF

chmod +x "$test_root/bin/noctalia" "$test_root/bin/game-performance" "$test_root/bin/test-game" \
	"$test_root/bin/test-game-wait" "$test_root/bin/desktop-focus-mode"

run_case() {
	local initial_dnd=$1 initial_focus=$2 expected=$3 status
	local case_name="${initial_dnd}-${initial_focus}"
	local log_file="$test_root/$case_name.log" runtime_dir="$test_root/$case_name-runtime"
	local dnd_state="$test_root/$case_name-dnd"
	mkdir -p "$runtime_dir"
	printf '%s\n' "$initial_dnd" >"$dnd_state"

	set +e
	PATH="$test_root/bin:$PATH" XDG_RUNTIME_DIR="$runtime_dir" TEST_LOG="$log_file" \
		TEST_DND_STATE="$dnd_state" TEST_FOCUS_INITIAL="$initial_focus" \
		"$game_run" -- test-game
	status=$?
	set -e

	[[ $status -eq 23 ]] || {
		printf 'FAIL (%s): se esperaba exit 23, se obtuvo %s\n' "$case_name" "$status" >&2
		return 1
	}

	actual=$(<"$log_file")
	[[ "$actual" == "$expected" ]] || {
		printf 'FAIL (%s): secuencia inesperada\nEsperada:\n%s\nActual:\n%s\n' \
			"$case_name" "$expected" "$actual" >&2
		return 1
	}
	if find "$runtime_dir/dotfiles-gaming-sessions" -maxdepth 1 -type f -name '[0-9]*' \
		-print -quit 2>/dev/null | grep -q .; then
		printf 'FAIL (%s): quedó una marca gaming obsoleta\n' "$case_name" >&2
		return 1
	fi
	[[ ! -e "$runtime_dir/dotfiles-gaming-sessions/.dnd-initial" ]]
}

run_case off off $'dnd:on\nperformance:start\ngame:running\ndnd:off'
run_case on off $'performance:start\ngame:running'
run_case off on $'focus:off\ndnd:on\nperformance:start\ngame:running\ndnd:off'

mode_output=$(PATH="$test_root/bin:$PATH" "$game_run" --gamescope --gamescope-mode 2560x1440@120 --dry-run -- test-game)
[[ "$mode_output" == *'gamescope -W 2560 -H 1440 -r 120 -f'* ]] || {
	printf '%s\n' 'FAIL: game-run no aplicó el modo Gamescope explícito.' >&2
	exit 1
}

# DND must never block a game. A failed activation is visible to the caller.
failure_runtime="$test_root/dnd-failure-runtime"
failure_dnd="$test_root/dnd-failure-state"
printf '%s\n' off >"$failure_dnd"
set +e
PATH="$test_root/bin:$PATH" XDG_RUNTIME_DIR="$failure_runtime" TEST_LOG="$test_root/dnd-failure.log" \
	TEST_DND_STATE="$failure_dnd" TEST_FOCUS_INITIAL=off TEST_DND_SET_FAIL=1 \
	"$game_run" -- test-game >"$test_root/dnd-failure.out" 2>"$test_root/dnd-failure.err"
failure_status=$?
set -e
[[ $failure_status -eq 23 ]]
grep -Fq 'No se pudo activar No molestar; el juego continúa.' "$test_root/dnd-failure.err"

# Dos wrappers comparten la propiedad: A puede acabar primero sin quitar DND a B.
concurrent_runtime="$test_root/concurrent-runtime"
concurrent_log="$test_root/concurrent.log"
concurrent_dnd="$test_root/concurrent-dnd"
mkdir -p "$concurrent_runtime"
printf '%s\n' off >"$concurrent_dnd"

PATH="$test_root/bin:$PATH" XDG_RUNTIME_DIR="$concurrent_runtime" \
	TEST_LOG="$concurrent_log" TEST_DND_STATE="$concurrent_dnd" TEST_FOCUS_INITIAL=off \
	TEST_GAME_ID=A TEST_GAME_STARTED="$test_root/a.started" TEST_GAME_RELEASE="$test_root/a.release" \
	"$game_run" -- test-game-wait &
a_pid=$!
for _ in {1..100}; do [[ -e "$test_root/a.started" ]] && break; sleep 0.02; done
[[ -e "$test_root/a.started" ]]

PATH="$test_root/bin:$PATH" XDG_RUNTIME_DIR="$concurrent_runtime" \
	TEST_LOG="$concurrent_log" TEST_DND_STATE="$concurrent_dnd" TEST_FOCUS_INITIAL=off \
	TEST_GAME_ID=B TEST_GAME_STARTED="$test_root/b.started" TEST_GAME_RELEASE="$test_root/b.release" \
	"$game_run" -- test-game-wait &
b_pid=$!
for _ in {1..100}; do [[ -e "$test_root/b.started" ]] && break; sleep 0.02; done
[[ -e "$test_root/b.started" ]]

: >"$test_root/a.release"
wait "$a_pid"
[[ "$(<"$concurrent_dnd")" == on ]] || {
	printf '%s\n' 'FAIL: A restauró DND mientras B seguía activo.' >&2
	exit 1
}
[[ $(grep -c '^dnd:off$' "$concurrent_log" || true) -eq 0 ]]

: >"$test_root/b.release"
wait "$b_pid"
[[ "$(<"$concurrent_dnd")" == off ]]
[[ $(grep -c '^dnd:off$' "$concurrent_log") -eq 1 ]]
[[ ! -e "$concurrent_runtime/dotfiles-gaming-sessions/.dnd-initial" ]]

printf '%s\n' 'PASS: game-run comparte DND entre sesiones y restaura el estado al terminar la última'
