#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/ensure-1password-tray"}
readonly dropin="$repo_root/hypr-common/.config/systemd/user/app-1password@autostart.service.d/10-noctalia-ready.conf"
readonly autostart="$repo_root/hypr-common/.config/hypr/config/autostart.lua"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/busctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
attempts=0
[[ -f "$TEST_ATTEMPTS" ]] && attempts=$(<"$TEST_ATTEMPTS")
attempts=$((attempts + 1))
printf '%s' "$attempts" >"$TEST_ATTEMPTS"
((attempts >= TEST_READY_AFTER))
EOF

cat >"$test_root/bin/1password" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$TEST_LOG"
EOF

cat >"$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'FAIL: ensure-1password-tray no debe reiniciar unidades.' >&2
exit 99
EOF

cat >"$test_root/bin/uwsm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'FAIL: la unidad XDG ya proporciona el ámbito de 1Password.' >&2
exit 99
EOF

chmod +x "$test_root/bin/"*

PATH="$test_root/bin:/usr/bin" TEST_ATTEMPTS="$test_root/attempts" \
	TEST_READY_AFTER=3 TEST_LOG="$test_root/launch.log" "$helper"
[[ $(<"$test_root/launch.log") == '--silent --disable-gpu' ]]
[[ $(<"$test_root/attempts") == 3 ]]

rm -f -- "$test_root/attempts" "$test_root/launch.log"
PATH="$test_root/bin:/usr/bin" TEST_ATTEMPTS="$test_root/attempts" \
	TEST_READY_AFTER=99 TEST_LOG="$test_root/launch.log" "$helper"
[[ ! -e "$test_root/launch.log" ]]

grep -Fqx 'ExecStart=%h/.local/bin/ensure-1password-tray' "$dropin"
if grep -Fq 'hl.exec_cmd("ensure-1password-tray")' "$autostart"; then
	printf '%s\n' 'FAIL: Hyprland no debe crear una segunda instancia de 1Password.' >&2
	exit 1
fi

printf '%s\n' 'PASS: 1Password espera al tray y arranca una sola instancia sin GPU'
