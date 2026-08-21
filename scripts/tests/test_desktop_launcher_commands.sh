#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly launcher=${1:-"$repo_root/hypr-common/.local/bin/desktop-launcher"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

for command in capture-context capture-qr bug-capsule media-convert local-dictation \
	desktop-focus-mode direct-scanout-toggle hypr-window-width; do
	cat >"$test_root/bin/$command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if (($#)); then
	printf '%s\t%s\n' "$(basename -- "$0")" "$*" >>"$TEST_LOG"
else
	printf '%s\n' "$(basename -- "$0")" >>"$TEST_LOG"
fi
EOF
	chmod +x "$test_root/bin/$command"
done

cat >"$test_root/bin/demo-studio" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == status ]]; then
	printf '%s\n' idle
	exit 0
fi
printf '%s\t%s\n' "$(basename -- "$0")" "$*" >>"$TEST_LOG"
EOF

cat >"$test_root/bin/appearance-switch" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == list ]]; then
	printf '%s\n' $'atlas\tAtlas\tcustom ProjectAtlas'
	exit 0
fi
printf '%s\t%s\n' "$(basename -- "$0")" "$*" >>"$TEST_LOG"
EOF

cat >"$test_root/bin/dev-ports" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == list ]]; then
	printf '%s\n' $'port_5173_pid_42_addr_127.0.0.1\tPort 5173 (127.0.0.1) - vite - demo' \
		$'port_5174_pid_42_addr_::1\tPort 5174 (::1) - vite - demo'
	exit 0
fi
printf '%s\t%s\n' "$(basename -- "$0")" "$*" >>"$TEST_LOG"
EOF

cat >"$test_root/bin/crash-context" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == list ]]; then
	printf '%s\n' $'4242-12-34\tpid=4242\tsignal=SIGSEGV\texe=/usr/bin/demo'
	exit 0
fi
printf '%s\t%s\n' "$(basename -- "$0")" "$*" >>"$TEST_LOG"
EOF
chmod +x "$test_root/bin/demo-studio" "$test_root/bin/appearance-switch" \
	"$test_root/bin/dev-ports" "$test_root/bin/crash-context"

cat >"$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'binds -j' ]]
cat <<'JSON'
[
  {"has_description":true,"modmask":77,"key":"7","description":"Toggle keybindings panel"},
  {"has_description":true,"modmask":8,"key":"H","description":"Move focus left"},
  {"has_description":true,"modmask":64,"key":"Space","description":"Toggle English and Spanish keyboard"},
  {"has_description":true,"modmask":0,"key":"Print","description":"Capture a region"},
  {"has_description":false,"modmask":4,"key":"X","description":"Do not show"}
]
JSON
EOF

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'noctalia\t%s\n' "$*" >>"$TEST_LOG"
if [[ "${TEST_TIMER_REPAIR:-0}" == 1 && "$*" == 'msg panel-toggle noctalia/timer:panel' ]]; then
	printf '%s\n' 'error: unknown panel "noctalia/timer:panel"' >&2
	exit 1
fi
if [[ "${TEST_TIMER_REPAIR:-0}" == 1 && "$*" == 'msg plugins enable noctalia/timer' ]]; then
	mkdir -p "$XDG_STATE_HOME/noctalia/plugins/materialized/official/timer"
	: >"$XDG_STATE_HOME/noctalia/plugins/materialized/official/timer/plugin.toml"
fi
EOF

chmod +x "$test_root/bin/hyprctl" "$test_root/bin/noctalia"

for command in whisper-cli wtype game-run; do
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$test_root/bin/$command"
	chmod +x "$test_root/bin/$command"
done

commands=$(PATH="$test_root/bin:$PATH" "$launcher" list commands)
for title in 'Capture context' 'Read QR code' 'Create bug capsule' \
	'Convert media' 'Demo Studio' 'Save window width' \
	'Restore window width' 'Toggle local dictation' 'Toggle focus mode' \
	'Prepare demo mode' 'Toggle direct scanout' 'Timer' 'Next appearance'; do
	grep -q "^${title}"$'\t' <<<"$commands" || {
		printf 'FAIL: falta %s en /cmd\n' "$title" >&2
		exit 1
	}
done
[[ $commands != *'capture_context'* && $commands != *'direct_scanout_toggle'* ]]

log=$test_root/actions.log
: >"$log"
for title in 'Capture context' 'Read QR code' 'Create bug capsule' \
	'Convert media' 'Demo Studio' 'Save window width' \
	'Restore window width' 'Toggle local dictation' 'Toggle focus mode' \
	'Prepare demo mode' 'Toggle direct scanout' 'Timer' 'Next appearance'; do
	selection=$(grep "^${title}"$'\t' <<<"$commands")
	PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run commands "$selection"
done

expected=$(cat <<'EOF'
capture-context	--focus orca
capture-qr
bug-capsule
media-convert
demo-studio	show
hypr-window-width	save
hypr-window-width	restore
local-dictation	toggle --paste
desktop-focus-mode	toggle
desktop-focus-mode	demo-toggle
direct-scanout-toggle	toggle
noctalia	msg panel-toggle noctalia/timer:panel
appearance-switch	next
EOF
)
actual=$(<"$log")
[[ "$actual" == "$expected" ]] || {
	printf 'FAIL: acciones inesperadas\nEsperadas:\n%s\nActuales:\n%s\n' "$expected" "$actual" >&2
	exit 1
}

: >"$log"
timer_selection=$(grep '^Timer'$'\t' <<<"$commands")
PATH="$test_root/bin:$PATH" TEST_LOG="$log" TEST_TIMER_REPAIR=1 \
	XDG_DATA_HOME="$test_root/data" XDG_STATE_HOME="$test_root/state" \
	"$launcher" run commands "$timer_selection"
expected_timer_repair=$(cat <<'EOF'
noctalia	msg panel-toggle noctalia/timer:panel
noctalia	msg plugins enable noctalia/timer
noctalia	msg config-reload
noctalia	msg panel-open noctalia/timer:panel
EOF
)
[[ $(<"$log") == "$expected_timer_repair" ]] || {
	printf 'FAIL: reparación inesperada de Timer\nEsperada:\n%s\nActual:\n%s\n' \
		"$expected_timer_repair" "$(<"$log")" >&2
	exit 1
}

: >"$log"
PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" open timer
[[ $(<"$log") == $'noctalia\tmsg panel-toggle noctalia/timer:panel' ]]

appearance=$(PATH="$test_root/bin:$PATH" "$launcher" list appearance)
ports=$(PATH="$test_root/bin:$PATH" "$launcher" list ports)
crashes=$(PATH="$test_root/bin:$PATH" "$launcher" list crashes)
[[ $appearance == $'Atlas\tApply coordinated palette and wallpapers' ]]
[[ $ports == $'Port 5173 (127.0.0.1) — vite — demo\tOpen local development server in the browser\nPort 5174 (::1) — vite — demo\tOpen local development server in the browser' ]]
[[ $crashes == $'Crash in demo\tSegmentation fault' ]]
[[ $appearance != *$'atlas\t'* && $ports != *'port_5173_pid_42'* && $crashes != *'4242-12-34'* ]]

categories=$(PATH="$test_root/bin:$PATH" "$launcher" list keybindings)
grep -Fxq $'Windows and focus\tMovement, size, and layout' <<<"$categories"
grep -Fxq $'Workspaces\tDesktops and special workspaces' <<<"$categories"
grep -Fxq $'Applications\tPrograms and launchers' <<<"$categories"
grep -Fxq $'Media and capture\tAudio, playback, images, and appearance' <<<"$categories"
grep -Fxq $'System and session\tInput, session, and utilities' <<<"$categories"
grep -Fxq $'All keybindings\tComplete list for global search' <<<"$categories"

keybindings=$(PATH="$test_root/bin:$PATH" "$launcher" list keybindings-all)
grep -Fxq $'Hyper + 7\tToggle keybindings panel' <<<"$keybindings"
grep -Fxq $'Alt + H\tMove focus left' <<<"$keybindings"
grep -Fxq $'Super + Space\tToggle English and Spanish keyboard' <<<"$keybindings"
grep -Fxq $'Print\tCapture a region' <<<"$keybindings"
[[ $keybindings != *'Do not show'* ]]
[[ $(PATH="$test_root/bin:$PATH" "$launcher" list keybindings-windows) == $'Alt + H\tMove focus left' ]]
[[ $(PATH="$test_root/bin:$PATH" "$launcher" list keybindings-media) == $'Print\tCapture a region' ]]
system_keys=$(PATH="$test_root/bin:$PATH" "$launcher" list keybindings-system)
grep -Fxq $'Hyper + 7\tToggle keybindings panel' <<<"$system_keys"
grep -Fxq $'Super + Space\tToggle English and Spanish keyboard' <<<"$system_keys"

navigation_log=$test_root/navigation.log
: >"$navigation_log"
PATH="$test_root/bin:$PATH" TEST_LOG="$navigation_log" "$launcher" run keybinding-categories \
	$'Windows and focus\tMovement, size, and layout'
[[ $(<"$navigation_log") == $'noctalia\tmsg panel-open launcher /keys-windows' ]]

: >"$log"
PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run appearance "$appearance"
PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run ports "$(tail -n 1 <<<"$ports")"
PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run crashes "$crashes"
[[ $(<"$log") == $'appearance-switch\tapply atlas\ndev-ports\topen port_5174_pid_42_addr_::1\ncrash-context\tselect 4242-12-34' ]]

python3 - "$repo_root" <<'PY'
from pathlib import Path
import sys
import tomllib

root = Path(sys.argv[1])
with (root / "noctalia/.config/noctalia/config.toml").open("rb") as source:
    config = tomllib.load(source)

entries = config["shell"]["launcher"]["dmenu"]["entry"]
expected = {
    "projects": ("Projects", "folder-code", 'desktop-launcher run projects "{selection}"'),
    "project_actions": ("Project actions", "tools", 'desktop-launcher run project-actions "{selection}"'),
    "ssh": ("SSH", "server", 'desktop-launcher run ssh "{selection}"'),
    "media": ("Media", "device-tv", 'desktop-launcher run media "{selection}"'),
    "typing": ("Typing", "keyboard", 'desktop-launcher run typing "{selection}"'),
    "appearance": ("Appearance", "palette", 'desktop-launcher run appearance "{selection}"'),
    "ports": ("Development ports", "world-www", 'desktop-launcher run ports "{selection}"'),
    "crashes": ("Recent crashes", "bug", 'desktop-launcher run crashes "{selection}"'),
    "share": ("Share", "share-2", 'desktop-launcher run share "{selection}"'),
    "commands": ("Commands", "terminal-2", 'desktop-launcher run commands "{selection}"'),
}
for name, (label, glyph, command) in expected.items():
    assert entries[name]["label"] == label
    assert entries[name]["glyph"] == glyph
    assert entries[name]["exec"] == command

entry = entries["keybindings"]
assert entry["prefix"] == "keys"
assert entry["command"] == "desktop-launcher list keybindings"
assert entry["exec"] == 'desktop-launcher run keybinding-categories "{selection}"'
for suffix in ("windows", "workspaces", "apps", "media", "system", "all"):
    child = entries[f"keybindings_{suffix}"]
    assert child["prefix"] == f"keys-{suffix}"
    assert child["command"] == f"desktop-launcher list keybindings-{suffix}"
    assert child["exec"] == "true"
    assert child["glyph"] == "keyboard"

helper = (root / "hypr-common/.local/bin/hypr-keybind-help").read_text(encoding="utf-8")
assert "panel-toggle launcher /keys" in helper
PY

printf '%s\n' 'PASS: launcher expone nombres descriptivos, atajos por función e identificadores internos revalidados'
