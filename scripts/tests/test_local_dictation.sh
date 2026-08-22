#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/local-dictation"}
test_root=$(mktemp -d)
zombie_holder_pid=''
cleanup() {
	if [[ -f "$test_root/state/recorder.pid" ]]; then
		read -r recorder_pid _ <"$test_root/state/recorder.pid"
		kill "$recorder_pid" 2>/dev/null || true
	fi
	[[ -z "${unrelated_pid:-}" ]] || kill "$unrelated_pid" 2>/dev/null || true
	[[ -z "$zombie_holder_pid" ]] || kill "$zombie_holder_pid" 2>/dev/null || true
	[[ -z "$zombie_holder_pid" ]] || wait "$zombie_holder_pid" 2>/dev/null || true
	rm -rf -- "$test_root"
}
trap cleanup EXIT

spawn_zombie() {
	local ready_file=$1
	python3 - "$ready_file" <<'PY' &
import os
import pathlib
import signal
import sys
import time

child = os.fork()
if child == 0:
    os._exit(0)

def clean_up(_signum, _frame):
    os.waitpid(child, 0)
    raise SystemExit(0)

signal.signal(signal.SIGTERM, clean_up)

deadline = time.monotonic() + 2
while time.monotonic() < deadline:
    try:
        state = pathlib.Path(f"/proc/{child}/stat").read_text().rsplit(") ", 1)[1].split()[0]
    except (FileNotFoundError, IndexError):
        state = ""
    if state == "Z":
        pathlib.Path(sys.argv[1]).write_text(f"{child}\n")
        break
    time.sleep(0.005)
else:
    raise SystemExit("no se pudo crear un proceso zombi")

signal.pause()
PY
	zombie_holder_pid=$!
	for _ in {1..200}; do
		[[ -s "$ready_file" ]] && return 0
		kill -0 "$zombie_holder_pid" 2>/dev/null || break
		sleep 0.01
	done
	printf '%s\n' 'FAIL: no se pudo preparar un proceso zombi' >&2
	return 1
}

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
while (($#)); do
	if [[ "$1" == -of ]]; then
		prefix=$2
		shift 2
		continue
	fi
	shift
done
[[ -n "$prefix" ]]
printf '%s\n' 'texto dictado de prueba' >"${prefix}.txt"
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
)

env "${common_env[@]}" "$helper" start
env "${common_env[@]}" "$helper" status | grep -Fxq recording
env "${common_env[@]}" "$helper" stop --paste

[[ "$(<"$test_root/clipboard")" == 'texto dictado de prueba' ]] || {
	printf '%s\n' 'FAIL: la transcripción no llegó al portapapeles' >&2
	exit 1
}
[[ "$(<"$test_root/typed")" == 'texto dictado de prueba' ]] || {
	printf '%s\n' 'FAIL: --paste no escribió la transcripción' >&2
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
[[ "$(<"$test_root/clipboard")" == 'texto dictado de prueba' ]]

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

# Un zombi conserva PID y starttime hasta que su padre lo recoge, pero no es
# una grabación viva y nunca debe llegar al envío de señales.
zombie_ready="$test_root/zombie.pid"
spawn_zombie "$zombie_ready"
zombie_pid=$(<"$zombie_ready")
zombie_starttime=$(awk '{ print $22 }' "/proc/$zombie_pid/stat")
printf '%s %s\n' "$zombie_pid" "$zombie_starttime" >"$test_root/state/recorder.pid"
set +e
env "${common_env[@]}" "$helper" stop >"$test_root/zombie.out" 2>"$test_root/zombie.err"
zombie_status=$?
set -e
if ! [[ $zombie_status -eq 2 ]] ||
	! grep -Fq 'No hay una grabación activa o su PID quedó obsoleta.' "$test_root/zombie.err"; then
	printf '%s\n' 'FAIL: un zombi se trató como una grabación activa' >&2
	exit 1
fi

printf '%s\n' 'PASS: local-dictation valida PID y modelo, graba, transcribe, copia y pega bajo demanda'
