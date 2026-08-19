#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly userscript=${1:-"$repo_root/qutebrowser/.local/share/qutebrowser/userscripts/yank-markdown-link"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin"
cat >"$test_root/bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >"$TEST_CLIPBOARD"
EOF
chmod +x "$test_root/bin/wl-copy"

clipboard="$test_root/clipboard"
PATH="$test_root/bin:$PATH" TEST_CLIPBOARD="$clipboard" \
	QUTE_URL='https://example.test/a_(b)?ref=1' \
	QUTE_SELECTED_TEXT='A [link] with \ slash' \
	"$userscript"

expected='[A \[link\] with \\ slash](<https://example.test/a_(b)>)'
actual=$(<"$clipboard")
[[ "$actual" == "$expected" ]] || {
	printf 'FAIL: Markdown inesperado\nEsperado: %s\nActual: %s\n' "$expected" "$actual" >&2
	exit 1
}

PATH="$test_root/bin:$PATH" TEST_CLIPBOARD="$clipboard" \
	QUTE_URL='https://example.test/path?keep=1&utm_source=test&blank=&gclid=track#section' \
	QUTE_TITLE='Título' "$userscript"
[[ "$(<"$clipboard")" == '[Título](<https://example.test/path?keep=1&blank=#section>)' ]] || {
	printf 'FAIL: no se limpiaron los parámetros de seguimiento: %s\n' "$(<"$clipboard")" >&2
	exit 1
}

set +e
PATH="$test_root/bin:$PATH" TEST_CLIPBOARD="$clipboard" QUTE_SELECTED_TEXT='sin url' "$userscript" >/dev/null 2>&1
missing_url_status=$?
set -e
[[ $missing_url_status -ne 0 ]] || {
	printf '%s\n' 'FAIL: el userscript aceptó una URL ausente.' >&2
	exit 1
}

printf '%s\n' 'PASS: yank-markdown-link copia Markdown sin construir comandos qutebrowser'
