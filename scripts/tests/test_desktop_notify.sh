#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$repo_root/shell/.local/bin/desktop-notify"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"
export TEST_LOG="$test_root/log"
cat >"$test_root/bin/notify-send" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TEST_LOG"
exit "${TEST_NOTIFY_STATUS:-0}"
MOCK
cat >"$test_root/bin/noctalia" <<'MOCK'
#!/usr/bin/env bash
printf 'noctalia:%s\n' "$*" >>"$TEST_LOG"
MOCK
chmod +x "$test_root/bin/"*
PATH="$test_root/bin:$PATH" "$helper" '-Backup' 'Falló el backup (código 1)'
expected=$'--app-name=dotfiles\n--urgency=normal\n--hint=boolean:transient:false\n--\n-Backup\nFalló el backup (código 1)'
[[ $(<"$TEST_LOG") == "$expected" ]]
# Delivery errors must not change the result of the task being reported.
PATH="$test_root/bin:$PATH" TEST_NOTIFY_STATUS=1 "$helper" Backup Error
grep -Fxq 'noctalia:msg notification-show Backup -- Error' "$TEST_LOG"
printf '%s\n' 'PASS: avisos normales conservables en historial; fallback sin propagar errores'
