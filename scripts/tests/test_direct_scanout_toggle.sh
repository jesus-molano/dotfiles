#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/direct-scanout-toggle"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"
printf '0\n' >"$test_root/value"

cat >"$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
"-j getoption render:direct_scanout")
	printf '{"int":%s}\n' "$(<"$TEST_VALUE")"
	;;
"keyword render:direct_scanout "*)
	printf '%s\n' "$3" >"$TEST_VALUE"
	printf 'hyprctl:%s\n' "$*" >>"$TEST_LOG"
	;;
*)
	printf 'Hyprctl inesperado: %s\n' "$*" >&2
	exit 2
	;;
esac
EOF

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'noctalia:%s\n' "$*" >>"$TEST_LOG"
EOF

chmod +x "$test_root/bin/hyprctl" "$test_root/bin/noctalia"

PATH="$test_root/bin:$PATH" TEST_VALUE="$test_root/value" TEST_LOG="$test_root/log" \
	"$helper" toggle
[[ "$(<"$test_root/value")" == 2 ]] || {
	printf '%s\n' 'FAIL: toggle no activó direct scanout.' >&2
	exit 1
}

status=$(PATH="$test_root/bin:$PATH" TEST_VALUE="$test_root/value" TEST_LOG="$test_root/log" \
	"$helper" status)
[[ "$status" == auto ]] || {
	printf 'FAIL: status esperaba auto, obtuvo %s\n' "$status" >&2
	exit 1
}

# Un valor heredado 1 debe declararse como activo y `toggle` debe apagarlo.
printf '1\n' >"$test_root/value"
legacy_status=$(PATH="$test_root/bin:$PATH" TEST_VALUE="$test_root/value" TEST_LOG="$test_root/log" \
	"$helper" status)
[[ "$legacy_status" == on ]] || {
	printf 'FAIL: status esperaba on para el valor 1, obtuvo %s\n' "$legacy_status" >&2
	exit 1
}
PATH="$test_root/bin:$PATH" TEST_VALUE="$test_root/value" TEST_LOG="$test_root/log" \
	"$helper" toggle
[[ "$(<"$test_root/value")" == 0 ]]

# Activa de nuevo el modo auto para comprobar su desactivación normal.
PATH="$test_root/bin:$PATH" TEST_VALUE="$test_root/value" TEST_LOG="$test_root/log" \
	"$helper" toggle

PATH="$test_root/bin:$PATH" TEST_VALUE="$test_root/value" TEST_LOG="$test_root/log" \
	"$helper" toggle
[[ "$(<"$test_root/value")" == 0 ]] || {
	printf '%s\n' 'FAIL: toggle no desactivó direct scanout.' >&2
	exit 1
}

expected=$'hyprctl:keyword render:direct_scanout 2\nnoctalia:msg notification-show Direct scanout -- Modo auto experimental: solo contenido game. Usa /cmd para desactivarlo si aparecen fallos gráficos.\nhyprctl:keyword render:direct_scanout 0\nnoctalia:msg notification-show Direct scanout -- Desactivado. La configuración persistente no se ha modificado.\nhyprctl:keyword render:direct_scanout 2\nnoctalia:msg notification-show Direct scanout -- Modo auto experimental: solo contenido game. Usa /cmd para desactivarlo si aparecen fallos gráficos.\nhyprctl:keyword render:direct_scanout 0\nnoctalia:msg notification-show Direct scanout -- Desactivado. La configuración persistente no se ha modificado.'
actual=$(<"$test_root/log")
[[ "$actual" == "$expected" ]] || {
	printf 'FAIL: llamadas inesperadas\nEsperada:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
	exit 1
}

printf '%s\n' 'PASS: direct scanout cambia solo en tiempo de ejecución y se puede revertir'
