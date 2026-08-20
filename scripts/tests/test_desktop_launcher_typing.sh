#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly launcher=${1:-"$repo_root/hypr-common/.local/bin/desktop-launcher"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/uwsm" <<'EOF'
#!/usr/bin/env bash
printf 'uwsm\t%s\n' "$*" >>"$TEST_LOG"
EOF
cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
printf 'noctalia\t%s\n' "$*" >>"$TEST_NOTIFICATION_LOG"
EOF
chmod +x "$test_root/bin/uwsm" "$test_root/bin/noctalia"

without_ttyper=$(PATH="$test_root/bin:$PATH" DESKTOP_LAUNCHER_TTYPER=missing-ttyper "$launcher" list typing)
[[ "$without_ttyper" == $'Keybr\tAdaptive typing practice' ]]
notification_log="$test_root/notification.log"
: >"$notification_log"
if PATH="$test_root/bin:$PATH" DESKTOP_LAUNCHER_TTYPER=missing-ttyper \
	TEST_NOTIFICATION_LOG="$notification_log" \
	"$launcher" run typing $'Ttyper — quick English\t50 words from english1000' >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: /typing ejecutó Ttyper aunque no estaba disponible.' >&2
	exit 1
fi
expected_notification=$'noctalia\tmsg notification-show Launcher -- Ttyper is not installed in this profile.'
[[ $(<"$notification_log") == "$expected_notification" ]] || {
	printf '%s\n' 'FAIL: /typing no capturó el aviso de Ttyper ausente.' >&2
	exit 1
}
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$test_root/bin/ttyper"
chmod +x "$test_root/bin/ttyper"

typing=$(PATH="$test_root/bin:$PATH" "$launcher" list typing)
expected_typing=$'Ttyper — quick English\t50 words from english1000\nTtyper — long English\t100 words from english1000\nTtyper — Python\t30 code words\nTtyper — JavaScript\t30 code words\nTtyper — Rust\t30 code words\nKeybr\tAdaptive typing practice'
[[ "$typing" == "$expected_typing" ]]

log="$test_root/typing.log"
: >"$log"
while IFS= read -r selection; do
	PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run typing "$selection"
done <<<"$typing"

expected=$(cat <<'EOF'
uwsm	app -- ghostty -e ttyper -l english1000 -w 50
uwsm	app -- ghostty -e ttyper -l english1000 -w 100
uwsm	app -- ghostty -e ttyper -l python -w 30
uwsm	app -- ghostty -e ttyper -l javascript -w 30
uwsm	app -- ghostty -e ttyper -l rust -w 30
uwsm	app -- /usr/bin/brave --app=https://www.keybr.com/
EOF
)
[[ $(<"$log") == "$expected" ]] || {
	printf 'FAIL: acciones inesperadas en /typing\nEsperadas:\n%s\nActuales:\n%s\n' \
		"$expected" "$(<"$log")" >&2
	exit 1
}

if PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run typing invalid >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: /typing aceptó una selección desconocida.' >&2
	exit 1
fi

printf '%s\n' 'PASS: /typing oculta Ttyper cuando falta y abre las acciones disponibles'
