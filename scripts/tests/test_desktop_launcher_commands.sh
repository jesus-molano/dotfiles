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
	printf '%s\n' $'port_5173_pid_42_addr_127.0.0.1\tPuerto 5173 (127.0.0.1) - vite - demo' \
		$'port_5174_pid_42_addr_::1\tPuerto 5174 (::1) - vite - demo'
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

for command in whisper-cli wtype game-run; do
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$test_root/bin/$command"
	chmod +x "$test_root/bin/$command"
done

commands=$(PATH="$test_root/bin:$PATH" "$launcher" list commands)
for token in capture_context capture_qr bug_capsule media_convert demo_studio \
	window_width_save window_width_restore dictation_toggle focus_toggle demo_mode direct_scanout_toggle; do
	grep -q "^${token}" <<<"$commands" || {
		printf 'FAIL: falta %s en /cmd\n' "$token" >&2
		exit 1
	}
done

log=$test_root/actions.log
: >"$log"
for token in capture_context capture_qr bug_capsule media_convert demo_studio \
	window_width_save window_width_restore dictation_toggle focus_toggle demo_mode direct_scanout_toggle; do
	PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run commands "$token"
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
EOF
)
actual=$(<"$log")
[[ "$actual" == "$expected" ]] || {
	printf 'FAIL: acciones inesperadas\nEsperadas:\n%s\nActuales:\n%s\n' "$expected" "$actual" >&2
	exit 1
}

[[ $(PATH="$test_root/bin:$PATH" "$launcher" list appearance) == $'atlas\tAtlas — custom ProjectAtlas' ]]
[[ $(PATH="$test_root/bin:$PATH" "$launcher" list ports) == $'port_5173_pid_42_addr_127.0.0.1\tPuerto 5173 (127.0.0.1) - vite - demo\nport_5174_pid_42_addr_::1\tPuerto 5174 (::1) - vite - demo' ]]
[[ $(PATH="$test_root/bin:$PATH" "$launcher" list crashes) == *'4242-12-34'* ]]

: >"$log"
PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run appearance atlas
PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run ports port_5174_pid_42_addr_::1
PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run crashes 4242-12-34
[[ $(<"$log") == $'appearance-switch\tapply atlas\ndev-ports\topen port_5174_pid_42_addr_::1\ncrash-context\tselect 4242-12-34' ]]

printf '%s\n' 'PASS: launcher expone herramientas, apariencias, puertos y crashes con tokens revalidados'
