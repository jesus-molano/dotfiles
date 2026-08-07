#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly game_run=${1:-"$repo_root/gaming/.local/bin/game-run"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == msg && "${2:-}" == notification-dnd-status ]]; then
	printf '%s\n' "${TEST_DND_INITIAL:-off}"
	exit 0
fi
if [[ "${1:-}" == msg && "${2:-}" == notification-dnd-set ]]; then
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

chmod +x "$test_root/bin/noctalia" "$test_root/bin/game-performance" "$test_root/bin/test-game"

run_case() {
	local initial_dnd=$1 expected=$2 status
	local log_file="$test_root/$initial_dnd.log"

	set +e
	PATH="$test_root/bin:$PATH" TEST_LOG="$log_file" TEST_DND_INITIAL="$initial_dnd" \
		"$game_run" -- test-game
	status=$?
	set -e

	[[ $status -eq 23 ]] || {
		printf 'FAIL (%s): se esperaba exit 23, se obtuvo %s\n' "$initial_dnd" "$status" >&2
		return 1
	}

	actual=$(<"$log_file")
	[[ "$actual" == "$expected" ]] || {
		printf 'FAIL (%s): secuencia inesperada\nEsperada:\n%s\nActual:\n%s\n' \
			"$initial_dnd" "$expected" "$actual" >&2
		return 1
	}
}

run_case off $'dnd:on\nperformance:start\ngame:running\ndnd:off'
run_case on $'performance:start\ngame:running'

printf '%s\n' 'PASS: game-run protege la sesión con DND y restaura el estado previo'
