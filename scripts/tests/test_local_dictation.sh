#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/local-dictation"}
test_root=$(mktemp -d)
cleanup() {
	if [[ -f "$test_root/state/recorder.pid" ]]; then
		read -r recorder_pid _ <"$test_root/state/recorder.pid"
		kill "$recorder_pid" 2>/dev/null || true
	fi
	[[ -z "${unrelated_pid:-}" ]] || kill "$unrelated_pid" 2>/dev/null || true
	rm -rf -- "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/bin" "$test_root/state" "$test_root/data"
printf 'model\n' >"$test_root/data/model.bin"

cat >"$test_root/bin/pw-record" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=${!#}
printf 'audio\n' >"$output"
trap 'exit 0' INT TERM
while :; do sleep 0.05; done
EOF

cat >"$test_root/bin/whisper-cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
prefix=''
printf '%s\n' "$@" >"$TEST_WHISPER_ARGS"
while (($#)); do
	if [[ "$1" == -of ]]; then
		prefix=$2
		shift 2
		continue
	fi
	shift
done
[[ -n "$prefix" ]]
printf '%s\n' \
	' texto dictado de prueba' \
	' con acento ningún' >"${prefix}.txt"
EOF

cat >"$test_root/bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >"$TEST_CLIPBOARD"
EOF

cat >"$test_root/bin/wtype" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == - ]]
cat >"$TEST_TYPED"
EOF

cat >"$test_root/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$test_root/bin/"*

common_env=(
	HOME="$test_root/home"
	PATH="$test_root/bin:$PATH"
	LOCAL_DICTATION_STATE_DIR="$test_root/state"
	LOCAL_DICTATION_MODEL="$test_root/data/model.bin"
	TEST_CLIPBOARD="$test_root/clipboard"
	TEST_TYPED="$test_root/typed"
	TEST_WHISPER_ARGS="$test_root/whisper-args"
)

env "${common_env[@]}" "$helper" start
env "${common_env[@]}" "$helper" status | grep -Fxq recording
env "${common_env[@]}" "$helper" stop --paste

awk '
	previous == "-l" && $0 == "es" { found = 1 }
	{ previous = $0 }
	END { exit !found }
' "$test_root/whisper-args" || {
	printf '%s\n' 'FAIL: Whisper no recibió el idioma español' >&2
	exit 1
}
awk '
	previous == "--prompt" && /Codex/ && /commit/ && /push/ && /TypeScript/ && /npm/ && /package.json/ { found = 1 }
	{ previous = $0 }
	END { exit !found }
' "$test_root/whisper-args" || {
	printf '%s\n' 'FAIL: Whisper no recibió el contexto técnico' >&2
	exit 1
}

[[ "$(<"$test_root/clipboard")" == 'texto dictado de prueba con acento ningún' ]] || {
	printf '%s\n' 'FAIL: la transcripción no llegó al portapapeles' >&2
	exit 1
}
[[ "$(<"$test_root/typed")" == 'texto dictado de prueba con acento ningún' ]] || {
	printf '%s\n' 'FAIL: --paste no escribió la transcripción normalizada' >&2
	exit 1
}
env "${common_env[@]}" "$helper" status | grep -Fxq idle

# Sin override, la selección persistente decide el modelo de Hyper+T.
mkdir -p "$test_root/model-state" "$test_root/model-data/whisper.cpp"
printf '%s\n' small >"$test_root/model-state/active-model"
selected_model=$(env \
	HOME="$test_root/home" \
	PATH="$test_root/bin:$PATH" \
	LOCAL_DICTATION_STATE_DIR="$test_root/selection-runtime" \
	LOCAL_DICTATION_HISTORY_DIR="$test_root/model-state" \
	XDG_DATA_HOME="$test_root/model-data" \
	"$helper" model)
[[ "$selected_model" == "$test_root/model-data/whisper.cpp/ggml-small.bin" ]] || {
	printf 'FAIL: la selección persistente devolvió %s\n' "$selected_model" >&2
	exit 1
}

env "${common_env[@]}" "$helper" toggle
env "${common_env[@]}" "$helper" toggle
[[ "$(<"$test_root/clipboard")" == 'texto dictado de prueba con acento ningún' ]]

# Una PID reutilizada u obsoleta nunca debe recibir señales.
sleep 30 &
unrelated_pid=$!
printf '%s %s\n' "$unrelated_pid" 1 >"$test_root/state/recorder.pid"
set +e
env "${common_env[@]}" "$helper" stop >/dev/null 2>&1
stale_status=$?
set -e
[[ $stale_status -ne 0 && -d "/proc/$unrelated_pid" ]] || {
	printf '%s\n' 'FAIL: una PID obsoleta afectó a otro proceso' >&2
	exit 1
}

printf '%s\n' 'PASS: local-dictation valida PID y modelo, graba, transcribe, copia y pega bajo demanda'
