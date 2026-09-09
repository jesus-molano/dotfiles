#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/capture-context"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/state" "$test_root/home/Pictures/Screenshots"
printf 'fake image\n' >"$test_root/input.png"

cat >"$test_root/bin/tesseract" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'Error E42 en el componente' 'segunda línea'
EOF

cat >"$test_root/bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$TEST_WL_COPY_ARGS"
[[ -z ${TEST_WL_COPY_SLEEP:-} ]] || sleep "$TEST_WL_COPY_SLEEP"
cat >"$TEST_CLIPBOARD"
EOF

cat >"$test_root/bin/date" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '2026-08-19_23-00-00'
EOF

cat >"$test_root/bin/hypr-chatgpt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' focused >"$TEST_ORCA_LOG"
EOF

cat >"$test_root/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$test_root/bin/"*

output=$(HOME="$test_root/home" \
	XDG_STATE_HOME="$test_root/state" \
	PATH="$test_root/bin:$PATH" \
	TEST_CLIPBOARD="$test_root/clipboard" \
	TEST_WL_COPY_ARGS="$test_root/wl-copy-args" \
	TEST_ORCA_LOG="$test_root/orca" \
	"$helper" --image "$test_root/input.png" --no-annotate --focus chatgpt --print)

latest="$test_root/state/desktop-context/latest.md"
[[ -f "$latest" ]] || {
	printf '%s\n' 'FAIL: no se creó latest.md' >&2
	exit 1
}
cmp -s "$latest" "$test_root/clipboard" || {
	printf '%s\n' 'FAIL: el portapapeles no contiene el contexto completo' >&2
	exit 1
}
[[ "$output" == "$(<"$latest")" ]] || {
	printf '%s\n' 'FAIL: --print no devolvió el contexto persistido' >&2
	exit 1
}
grep -Fxq -- '--sensitive --paste-once' "$test_root/wl-copy-args"
grep -Fq 'Error E42 en el componente' "$latest"
grep -Fq 'segunda línea' "$latest"
grep -Fq '![Captura]' "$latest"
[[ "$(<"$test_root/orca")" == focused ]]

cat >"$test_root/bin/tesseract" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'FAIL: OCR ejecutado con --no-ocr' >&2
exit 99
EOF
chmod +x "$test_root/bin/tesseract"

HOME="$test_root/home" \
	XDG_STATE_HOME="$test_root/state" \
	PATH="$test_root/bin:$PATH" \
	TEST_CLIPBOARD="$test_root/clipboard" \
	TEST_WL_COPY_ARGS="$test_root/wl-copy-args" \
	"$helper" --image "$test_root/input.png" --no-annotate --no-ocr >/dev/null

if grep -Fq 'Error E42' "$latest"; then
	printf '%s\n' 'FAIL: --no-ocr conservó texto anterior' >&2
	exit 1
fi

# Dos procesos en el mismo segundo deben reservar imágenes distintas.
HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" PATH="$test_root/bin:$PATH" \
	TEST_CLIPBOARD="$test_root/clipboard-1" TEST_WL_COPY_ARGS="$test_root/wl-copy-args-1" \
	TEST_WL_COPY_SLEEP=0.2 \
	"$helper" --image "$test_root/input.png" --no-annotate --no-ocr --print \
	>"$test_root/output-1" &
pid_1=$!
HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" PATH="$test_root/bin:$PATH" \
	TEST_CLIPBOARD="$test_root/clipboard-2" TEST_WL_COPY_ARGS="$test_root/wl-copy-args-2" \
	"$helper" --image "$test_root/input.png" --no-annotate --no-ocr --print \
	>"$test_root/output-2" &
pid_2=$!
wait "$pid_1" "$pid_2"
mapfile -t images < <(find "$test_root/home/Pictures/Screenshots" -maxdepth 1 -type f \
	-name 'context-2026-08-19_23-00-00-*.png' -printf '%f\n' | sort -u)
[[ ${#images[@]} -eq 4 ]]
cmp -s "$test_root/output-1" "$test_root/clipboard-1"
cmp -s "$test_root/output-2" "$test_root/clipboard-2"
if cmp -s "$test_root/output-1" "$test_root/output-2"; then
	printf '%s\n' 'FAIL: dos capturas compartieron el mismo contexto privado.' >&2
	exit 1
fi
printf '%s\n' 'PASS: capture-context guarda, copia y enfoca sin enviar datos'
