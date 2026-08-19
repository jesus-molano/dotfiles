#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly launcher=${1:-"$repo_root/hypr-common/.local/bin/desktop-launcher"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

for command in capture-context local-dictation desktop-focus-mode direct-scanout-toggle; do
	cat >"$test_root/bin/$command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t%s\n' "$(basename -- "$0")" "$*" >>"$TEST_LOG"
EOF
	chmod +x "$test_root/bin/$command"
done

for command in whisper-cli wtype game-run; do
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$test_root/bin/$command"
	chmod +x "$test_root/bin/$command"
done

commands=$(PATH="$test_root/bin:$PATH" "$launcher" list commands)
for token in capture_context dictation_toggle focus_toggle demo_mode direct_scanout_toggle; do
	grep -q "^${token}" <<<"$commands" || {
		printf 'FAIL: falta %s en /cmd\n' "$token" >&2
		exit 1
	}
done

log=$test_root/actions.log
: >"$log"
for token in capture_context dictation_toggle focus_toggle demo_mode direct_scanout_toggle; do
	PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run commands "$token"
done

expected=$(cat <<'EOF'
capture-context	--focus orca
local-dictation	toggle --paste
desktop-focus-mode	toggle
desktop-focus-mode	demo
direct-scanout-toggle	toggle
EOF
)
actual=$(<"$log")
[[ "$actual" == "$expected" ]] || {
	printf 'FAIL: acciones inesperadas\nEsperadas:\n%s\nActuales:\n%s\n' "$expected" "$actual" >&2
	exit 1
}

printf '%s\n' 'PASS: /cmd expone captura, dictado y modos reversibles'
