#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly dev_ports=${1:-"$repo_root/hypr-common/.local/bin/dev-ports"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/proc/101" "$test_root/proc/202" "$test_root/proc/303" "$test_root/bin" "$test_root/worktree/.git"

printf '%s\n' 'vite server' >"$test_root/proc/101/comm"
printf '%s\n' 'system daemon' >"$test_root/proc/202/comm"
printf '%s\n' 'steamwebhelper' >"$test_root/proc/303/comm"
ln -s "$test_root/worktree" "$test_root/proc/101/cwd"
ln -s / "$test_root/proc/202/cwd"
ln -s / "$test_root/proc/303/cwd"
cat >"$test_root/ss-output" <<'EOF'
LISTEN 0 511 127.0.0.1:5173 0.0.0.0:* users:(("node",pid=101,fd=21))
LISTEN 0 511 0.0.0.0:3000 0.0.0.0:* users:(("node",pid=101,fd=20))
LISTEN 0 511 [::1]:5174 [::]:* users:(("node",pid=101,fd=22))
LISTEN 0 511 [::]:4173 [::]:* users:(("node",pid=101,fd=23))
LISTEN 0 511 192.168.1.30:5000 0.0.0.0:* users:(("node",pid=101,fd=24))
LISTEN 0 128 0.0.0.0:8080 0.0.0.0:* users:(("root-service",pid=202,fd=3))
LISTEN 0 128 127.0.0.1:27060 0.0.0.0:* users:(("steamwebhelper",pid=303,fd=8))
EOF
cat >"$test_root/bin/opener" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$TEST_OPENER_LOG"
EOF
cat >"$test_root/bin/stat" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${!#}" in
*/202) printf '%s\n' 0 ;;
*) /usr/bin/stat "$@" ;;
esac
EOF
cat >"$test_root/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == -C && "$2" == "$TEST_WORKTREE" && "$*" == *'rev-parse --is-inside-work-tree'* ]] || exit 2
printf '%s\n' true
EOF
chmod +x "$test_root/bin/opener" "$test_root/bin/stat" "$test_root/bin/git"

common_env=(
	"DEV_PORTS_PROC_ROOT=$test_root/proc"
	"DEV_PORTS_SS_FILE=$test_root/ss-output"
	"DEV_PORTS_SHOW_TEXT=1"
	"DEV_PORTS_OPENER=$test_root/bin/opener"
	"TEST_WORKTREE=$test_root/worktree"
	"PATH=$test_root/bin:$PATH"
)

listed=$(env "${common_env[@]}" "$dev_ports" list)
expected=$'port_3000_pid_101_addr_0.0.0.0\tPort 3000 (0.0.0.0) - vite server - worktree\nport_4173_pid_101_addr_::\tPort 4173 (::) - vite server - worktree\nport_5000_pid_101_addr_192.168.1.30\tPort 5000 (192.168.1.30) - vite server - worktree\nport_5173_pid_101_addr_127.0.0.1\tPort 5173 (127.0.0.1) - vite server - worktree\nport_5174_pid_101_addr_::1\tPort 5174 (::1) - vite server - worktree'
[[ "$listed" == "$expected" ]] || {
	printf 'FAIL: lista inesperada:\n%s\n' "$listed" >&2
	exit 1
}

shown=$(env "${common_env[@]}" "$dev_ports" show)
[[ "$shown" == "$expected" ]] || {
	printf 'FAIL: show de texto inesperado:\n%s\n' "$shown" >&2
	exit 1
}

log="$test_root/opener.log"
env "${common_env[@]}" "TEST_OPENER_LOG=$log" "$dev_ports" open port_5173_pid_101_addr_127.0.0.1
[[ "$(<"$log")" == 'http://127.0.0.1:5173' ]] || {
	printf 'FAIL: URL abierta inesperada: %s\n' "$(<"$log")" >&2
	exit 1
}

env "${common_env[@]}" "TEST_OPENER_LOG=$log" "$dev_ports" open port_3000_pid_101_addr_0.0.0.0
[[ "$(<"$log")" == 'http://127.0.0.1:3000' ]] || {
	printf 'FAIL: URL IPv4 wildcard inesperada: %s\n' "$(<"$log")" >&2
	exit 1
}

env "${common_env[@]}" "TEST_OPENER_LOG=$log" "$dev_ports" open port_5000_pid_101_addr_192.168.1.30
[[ "$(<"$log")" == 'http://192.168.1.30:5000' ]] || {
	printf 'FAIL: URL IPv4 concreta inesperada: %s\n' "$(<"$log")" >&2
	exit 1
}

env "${common_env[@]}" "TEST_OPENER_LOG=$log" "$dev_ports" open port_5174_pid_101_addr_::1
[[ "$(<"$log")" == 'http://[::1]:5174' ]] || {
	printf 'FAIL: URL IPv6 loopback inesperada: %s\n' "$(<"$log")" >&2
	exit 1
}

env "${common_env[@]}" "TEST_OPENER_LOG=$log" "$dev_ports" open port_4173_pid_101_addr_::
[[ "$(<"$log")" == 'http://[::1]:4173' ]] || {
	printf 'FAIL: URL IPv6 wildcard inesperada: %s\n' "$(<"$log")" >&2
	exit 1
}

set +e
env "${common_env[@]}" "$dev_ports" open port_8080_pid_202_addr_0.0.0.0 >/dev/null 2>&1
foreign_status=$?
set -e
[[ $foreign_status -ne 0 ]] || {
	printf '%s\n' 'FAIL: open aceptó un proceso de otro usuario.' >&2
	exit 1
}

: >"$test_root/ss-output"
set +e
env "${common_env[@]}" "$dev_ports" open port_5173_pid_101_addr_127.0.0.1 >/dev/null 2>&1
missing_status=$?
set -e
[[ $missing_status -ne 0 ]] || {
	printf '%s\n' 'FAIL: open aceptó un token que ya no está vivo.' >&2
	exit 1
}

printf '%s\n' 'PASS: dev-ports filtra el usuario y listeners ajenos al desarrollo, etiqueta repositorios y revalida tokens'
