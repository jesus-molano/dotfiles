#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/crash-context"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/state"

cat >"$test_root/bin/coredumpctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *' list '* ]]; then
	count=0; [[ ! -f "$TEST_LIST_COUNT" ]] || count=$(<"$TEST_LIST_COUNT")
	count=$((count + 1)); printf '%s\n' "$count" >"$TEST_LIST_COUNT"
	if [[ "${TEST_CHANGED_AFTER_FIRST:-0}" == 1 && $count -gt 1 ]]; then
		printf '%s\n' '[{"time":1787170222077012,"pid":777,"sig":6,"exe":"/usr/bin/other"}]'
	else
		printf '%s\n' '[{"time":1787170221077012,"pid":4242,"sig":11,"exe":"/usr/bin/demo"},{"time":1787170220077012,"pid":4242,"sig":6,"exe":"/usr/bin/demo"}]'
	fi
	exit 0
fi
if [[ " $* " == *' --since @1787170221.077012 --until @1787170221.077012 info 4242 '* ]]; then
	printf '%s\n' "$*" >"$TEST_INFO_ARGS"
	printf '%s\n' '           PID: 4242 (demo)' '        Signal: 11 (SEGV)' '    Executable: /usr/bin/demo' '   Command Line: /usr/bin/demo --token secret' '       Message: private stack text'
	exit 0
fi
exit 2
EOF
cat >"$test_root/bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$TEST_WL_COPY_ARGS"
cat >"$TEST_CLIPBOARD"
EOF
cat >"$test_root/bin/hypr-orca" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' focused >"$TEST_ORCA_LOG"
EOF
chmod +x "$test_root/bin/"*

env_base=(PATH="$test_root/bin:$PATH" XDG_STATE_HOME="$test_root/state" TEST_LIST_COUNT="$test_root/list-count" TEST_CLIPBOARD="$test_root/clipboard" TEST_WL_COPY_ARGS="$test_root/wl-copy-args" TEST_ORCA_LOG="$test_root/orca" TEST_INFO_ARGS="$test_root/info-args")
listed=$(env "${env_base[@]}" "$helper" list)
token=${listed%%$'\t'*}
[[ "$listed" == *'pid=4242'* && "$listed" == *'exe=/usr/bin/demo'* ]]
[[ "$listed" == *'signal=11'* && "$listed" == *'time='* && "$listed" != *$'time=\n'* ]]
[[ $(grep -c $'\tpid=4242\t' <<<"$listed") -eq 2 ]]
[[ ! -e "$test_root/orca" ]] || { printf 'FAIL: list enfocó Orca\n' >&2; exit 1; }

env "${env_base[@]}" "$helper" select "$token" >/dev/null
latest="$test_root/state/crash-context/latest.md"
cmp -s "$latest" "$test_root/clipboard"
grep -Fq -- "- PID: \`4242\`" "$latest"
grep -Fq -- "- Señal: \`11\`" "$latest"
grep -Fq 'Executable: /usr/bin/demo' "$latest"
if grep -Fq 'secret' "$latest" || grep -Fq 'private stack' "$latest"; then
	printf '%s\n' 'FAIL: el resumen incluyó campos privados de coredumpctl.' >&2
	exit 1
fi
grep -Fq -- '--sensitive --paste-once' "$test_root/wl-copy-args"
[[ $(grep -c 'PID: 4242' "$latest") -eq 1 ]]
grep -Fq -- '--since @1787170221.077012 --until @1787170221.077012 info 4242' "$test_root/info-args"
[[ "$(<"$test_root/orca")" == focused ]]

rm -f -- "$test_root/list-count" "$test_root/orca" "$test_root/clipboard"
changed_output=$(set +e; env "${env_base[@]}" TEST_CHANGED_AFTER_FIRST=1 "$helper" select "$token" 2>&1; printf '\nstatus=%s' "$?")
[[ "$changed_output" == *'status=3'* ]] || { printf 'FAIL: no rechazó token caducado\n%s\n' "$changed_output" >&2; exit 1; }
[[ ! -e "$test_root/orca" && ! -e "$test_root/clipboard" ]] || { printf 'FAIL: token caducado copió o enfocó Orca\n' >&2; exit 1; }
printf '%s\n' 'PASS: crash-context lista, revalida, copia y enfoca solo tras selección'
