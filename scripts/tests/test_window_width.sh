#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/hypr-window-width"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/state"

cat >"$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 ${2:-}" in
'activewindow -j') printf '%s\n' "${TEST_ACTIVE_WINDOW}" ;;
'dispatch resizeactive') printf 'dispatch\t%s\n' "$*" >>"$TEST_LOG" ;;
*) exit 2 ;;
esac
EOF
cat >"$test_root/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$test_root/bin/hyprctl" "$test_root/bin/notify-send"

active='{"class":"org.example.Editor","workspace":{"id":4},"size":[777,555]}'
env_base=(PATH="$test_root/bin:$PATH" XDG_STATE_HOME="$test_root/state" TEST_ACTIVE_WINDOW="$active" TEST_LOG="$test_root/log")
env "${env_base[@]}" "$helper" save >/dev/null

active='{"class":"org.example.Editor","workspace":{"id":4},"size":[333,555]}'
env "${env_base[@]}" TEST_ACTIVE_WINDOW="$active" "$helper" restore >/dev/null
grep -Fqx $'dispatch\tdispatch resizeactive exact 777 555' "$test_root/log"

other='{"class":"org.example.Editor","workspace":{"id":5},"size":[333,555]}'
set +e
env "${env_base[@]}" TEST_ACTIVE_WINDOW="$other" "$helper" restore >/dev/null 2>&1
status=$?
set -e
[[ $status -eq 3 ]] || { printf 'FAIL: restore aceptó otro espacio de trabajo\n' >&2; exit 1; }
printf '%s\n' 'PASS: hypr-window-width separa estado y restaura un tamaño exacto'
