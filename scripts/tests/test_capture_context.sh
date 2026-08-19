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
cat >"$TEST_CLIPBOARD"
EOF

cat >"$test_root/bin/hypr-orca" <<'EOF'
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
	TEST_ORCA_LOG="$test_root/orca" \
	"$helper" --image "$test_root/input.png" --no-annotate --focus orca --print)

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
	"$helper" --image "$test_root/input.png" --no-annotate --no-ocr >/dev/null

if grep -Fq 'Error E42' "$latest"; then
	printf '%s\n' 'FAIL: --no-ocr conservó texto anterior' >&2
	exit 1
fi
printf '%s\n' 'PASS: capture-context guarda, copia y enfoca sin enviar datos'
