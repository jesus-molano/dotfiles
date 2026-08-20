#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly starter=${1:-"$repo_root/hypr-common/.local/bin/start-orca-background"}
readonly launcher=${2:-"$repo_root/hypr-common/.local/bin/hypr-orca"}
readonly autostart="$repo_root/hypr-common/.config/hypr/config/autostart.lua"
readonly windowrules="$repo_root/hypr-common/.config/hypr/config/windowrules.lua"
readonly user_binds="$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/orca-safe-settings" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' safe-settings >>"$TEST_LOG"
EOF

cat >"$test_root/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
printf 'pgrep:%s\n' "$*" >>"$TEST_LOG"
exit "${TEST_PGREP_STATUS:-1}"
EOF

cat >"$test_root/bin/orca-ide" <<'EOF'
#!/usr/bin/env bash
printf 'orca:%s\n' "$*" >>"$TEST_LOG"
EOF

cat >"$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
clients) cat "$TEST_CLIENTS" ;;
eval) printf 'hyprctl:%s\n' "$2" >>"$TEST_LOG" ;;
*) exit 2 ;;
esac
EOF

cat >"$test_root/bin/uwsm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'uwsm:%s\n' "$*" >>"$TEST_LOG"
cat >"$TEST_CLIENTS" <<'JSON'
[{"class":"orca","initialClass":"orca","workspace":{"name":"special:orca"}}]
JSON
EOF

chmod +x "$test_root/bin/"*

TEST_LOG="$test_root/starter-new.log" TEST_PGREP_STATUS=1 \
	ORCA_SAFE_SETTINGS_BIN="$test_root/bin/orca-safe-settings" \
	PGREP_BIN="$test_root/bin/pgrep" ORCA_CLI_BIN="$test_root/bin/orca-ide" \
	"$starter"
[[ $(<"$test_root/starter-new.log") == $'safe-settings\npgrep:-f [/]orca-ide$\norca:open' ]]

TEST_LOG="$test_root/starter-running.log" TEST_PGREP_STATUS=0 \
	ORCA_SAFE_SETTINGS_BIN="$test_root/bin/orca-safe-settings" \
	PGREP_BIN="$test_root/bin/pgrep" ORCA_CLI_BIN="$test_root/bin/orca-ide" \
	"$starter"
[[ $(<"$test_root/starter-running.log") == $'safe-settings\npgrep:-f [/]orca-ide$' ]]

printf '%s\n' '[{"class":"orca","initialClass":"orca","workspace":{"name":"special:orca"}}]' \
	>"$test_root/clients.json"
TEST_LOG="$test_root/launcher-special.log" TEST_CLIENTS="$test_root/clients.json" \
	HYPRCTL_BIN="$test_root/bin/hyprctl" ORCA_SAFE_SETTINGS_BIN="$test_root/bin/orca-safe-settings" \
	UWSM_BIN="$test_root/bin/uwsm" ORCA_CLI_BIN="$test_root/bin/orca-ide" \
	"$launcher"
grep -Fqx 'hyprctl:hl.dispatch(hl.dsp.workspace.toggle_special("orca"))' \
	"$test_root/launcher-special.log"

printf '%s\n' '[]' >"$test_root/clients.json"
TEST_LOG="$test_root/launcher-new.log" TEST_CLIENTS="$test_root/clients.json" \
	HYPRCTL_BIN="$test_root/bin/hyprctl" ORCA_SAFE_SETTINGS_BIN="$test_root/bin/orca-safe-settings" \
	UWSM_BIN="$test_root/bin/uwsm" ORCA_CLI_BIN="$test_root/bin/orca-ide" \
	"$launcher"
grep -Fqx 'safe-settings' "$test_root/launcher-new.log"
grep -Fqx "uwsm:app -- $test_root/bin/orca-ide open" "$test_root/launcher-new.log"
grep -Fqx 'hyprctl:hl.dispatch(hl.dsp.workspace.toggle_special("orca"))' \
	"$test_root/launcher-new.log"

grep -Fq 'hl.exec_cmd("uwsm app -- start-orca-background")' "$autostart"
grep -Fq 'name = "route-orca-to-background"' "$windowrules"
grep -Fq 'workspace = "special:orca silent"' "$windowrules"
grep -Fq 'bind(hyper .. " + O", hl.dsp.exec_cmd("hypr-orca")' "$user_binds"

printf '%s\n' 'PASS: Orca arranca oculta y Hyper+O revela su workspace especial'
