#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bin="$repo_root/hypr-common/.local/bin"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"
export TEST_LOG="$test_root/log" TEST_CLIENTS="$test_root/clients"
export TEST_VISIBLE=false
cat >"$test_root/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
case "$1" in
clients) cat "$TEST_CLIENTS" ;;
monitors) if [[ $TEST_VISIBLE == true ]]; then printf '%s\n' '[{"specialWorkspace":{"name":"special:chatgpt"}}]'; else printf '[]\n'; fi ;;
eval) printf '%s\n' "$2" >>"$TEST_LOG" ;;
*) exit 2 ;;
esac
SH
cat >"$test_root/bin/app" <<'SH'
#!/usr/bin/env bash
printf 'app:%s\n' "$*" >>"$TEST_LOG"
SH
cat >"$test_root/bin/pgrep" <<'SH'
#!/usr/bin/env bash
exit "${TEST_RUNNING:-1}"
SH
cat >"$test_root/bin/uwsm" <<'SH'
#!/usr/bin/env bash
printf 'uwsm:%s\n' "$*" >>"$TEST_LOG"
printf '%s\n' '[{"class":"codex-desktop","workspace":{"name":"special:chatgpt"}}]' >"$TEST_CLIENTS"
SH
chmod +x "$test_root/bin/"*
export HYPRCTL_BIN="$test_root/bin/hyprctl" CHATGPT_BIN="$test_root/bin/app" UWSM_BIN="$test_root/bin/uwsm"
export PGREP_BIN="$test_root/bin/pgrep" CHATGPT_RUNTIME="$test_root/bin/app"
: >"$TEST_LOG"
TEST_RUNNING=0 "$bin/start-chatgpt-background"
[[ ! -s $TEST_LOG ]]
TEST_RUNNING=1 "$bin/start-chatgpt-background"
grep -Fxq 'app:' "$TEST_LOG"
: >"$TEST_LOG"
CHATGPT_RUNTIME="$test_root/absent" "$bin/start-chatgpt-background" 2>"$test_root/missing"
[[ ! -s $TEST_LOG ]]
grep -q 'no está instalado' "$test_root/missing"
# A closed overlay is revealed without starting a second instance.
printf '%s\n' '[{"class":"codex-desktop","workspace":{"name":"special:chatgpt"}}]' >"$TEST_CLIENTS"
"$bin/hypr-chatgpt"
grep -Fq 'toggle_special("chatgpt")' "$TEST_LOG"
if grep -q uwsm "$TEST_LOG"; then exit 1; fi
# Capture/project focus must not hide an already visible overlay.
: >"$TEST_LOG"
TEST_VISIBLE=true "$bin/hypr-chatgpt" --focus
if grep -q toggle_special "$TEST_LOG"; then exit 1; fi
# A normal workspace is focused rather than moved.
printf '%s\n' '[{"class":"codex-desktop","workspace":{"name":"2"}}]' >"$TEST_CLIENTS"
"$bin/hypr-chatgpt" --focus
grep -Fq 'hl.dsp.focus' "$TEST_LOG"
# A missing instance is started, then revealed.
printf '[]\n' >"$TEST_CLIENTS"
: >"$TEST_LOG"
"$bin/hypr-chatgpt"
grep -Fq "uwsm:app -- $CHATGPT_BIN" "$TEST_LOG"
grep -Fq 'toggle_special("chatgpt")' "$TEST_LOG"
# URI arguments reach a running app, without treating them as shell code.
: >"$TEST_LOG"
"$bin/hypr-chatgpt" --focus 'codex://example?value=a%20b'
grep -Fq 'codex://example?value=a%20b' "$TEST_LOG"
grep -Fq 'start-chatgpt-background' "$repo_root/hypr-common/.config/hypr/config/autostart.lua"
if grep -q 'start-orca' "$repo_root/hypr-common/.config/hypr/config/autostart.lua"; then exit 1; fi
grep -Fq 'special:chatgpt silent' "$repo_root/hypr-common/.config/hypr/config/windowrules.lua"
if grep -q 'special:orca' "$repo_root/hypr-common/.config/hypr/config/windowrules.lua"; then exit 1; fi
grep -Fq 'hyper .. " + W", hl.dsp.exec_cmd("hypr-chatgpt")' "$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
if grep -q 'hypr-orca' "$repo_root/hypr-common/.config/hypr/config/user-binds.lua"; then exit 1; fi
desktop-file-validate "$repo_root/hypr-common/.local/share/applications/codex-desktop.desktop"
[[ $(grep -c '^Exec=.*CODEX_LINUX_DISABLE_USAGE_REPORTING=1' "$repo_root/hypr-common/.local/share/applications/codex-desktop.desktop") == 2 ]]
printf '%s\n' 'PASS: ChatGPT inicia oculto; Hyper+W alterna, --focus conserva visible y Orca queda fuera del arranque'
