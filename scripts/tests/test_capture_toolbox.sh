#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
qr=${1:-"$repo_root/hypr-common/.local/bin/capture-qr"}
convert=${2:-"$repo_root/hypr-common/.local/bin/media-convert"}
capsule=${3:-"$repo_root/hypr-common/.local/bin/bug-capsule"}
test_root=$(mktemp -d)
cleanup() {
	status=$?
	rm -rf -- "$test_root"
	exit "$status"
}
trap cleanup EXIT
mkdir -p "$test_root/bin" "$test_root/out" "$test_root/home"

write_mock() { printf '%s\n' "$2" >"$test_root/bin/$1"; chmod +x "$test_root/bin/$1"; }
write_mock slurp '#!/usr/bin/env bash
printf "%s\\n" "10,10 20x20"'
write_mock grim '#!/usr/bin/env bash
printf image >"${@: -1}"'
write_mock zbarimg '#!/usr/bin/env bash
printf "%s\\n" "otpauth://secret-value"'
write_mock wl-copy '#!/usr/bin/env bash
[[ -z "${TEST_WL_COPY_ARGS:-}" ]] || printf "%s\\n" "$*" >"$TEST_WL_COPY_ARGS"
cat >"$TEST_CLIPBOARD"'
write_mock notify-send '#!/usr/bin/env bash
exit 0'
write_mock date '#!/usr/bin/env bash
printf "%s\\n" "2026-08-19_23-00-00"'

PATH="$test_root/bin:$PATH" TEST_CLIPBOARD="$test_root/qr-clipboard" TEST_WL_COPY_ARGS="$test_root/qr-args" CAPTURE_QR_RUNTIME_DIR="$test_root" "$qr" >"$test_root/qr-output"
[[ ! -s "$test_root/qr-output" ]]
[[ "$(<"$test_root/qr-clipboard")" == otpauth://secret-value ]]
grep -Fq -- '--sensitive --paste-once' "$test_root/qr-args"

printf image >"$test_root/input.png"
write_mock file '#!/usr/bin/env bash
printf "%s\\n" image/png'
write_mock magick '#!/usr/bin/env bash
[[ "${TEST_MAGICK_SLEEP:-0}" == 0 ]] || sleep "$TEST_MAGICK_SLEEP"
printf converted >"${@: -1}"'
write_mock python3 '#!/usr/bin/env bash
printf "file://%s\\n" "$2"'
converted=$(PATH="$test_root/bin:$PATH" TEST_CLIPBOARD="$test_root/media-clipboard" "$convert" --input "$test_root/input.png" --format jpg --size 720 --output-dir "$test_root/out")
[[ -s "$converted" ]]
[[ "$(<"$test_root/media-clipboard")" == "file://$converted" ]]

PATH="$test_root/bin:$PATH" TEST_CLIPBOARD="$test_root/media-clipboard-1" TEST_MAGICK_SLEEP=0.2 \
	"$convert" --input "$test_root/input.png" --format jpg --size 720 --output-dir "$test_root/out" >"$test_root/output-1" &
convert_pid_1=$!
PATH="$test_root/bin:$PATH" TEST_CLIPBOARD="$test_root/media-clipboard-2" TEST_MAGICK_SLEEP=0.2 \
	"$convert" --input "$test_root/input.png" --format jpg --size 720 --output-dir "$test_root/out" >"$test_root/output-2" &
convert_pid_2=$!
wait "$convert_pid_1"
wait "$convert_pid_2"
converted_1=$(<"$test_root/output-1")
converted_2=$(<"$test_root/output-2")
[[ "$converted_1" != "$converted_2" && -s "$converted_1" && -s "$converted_2" ]]

printf screenshot >"$test_root/screenshot.png"
write_mock capture-context $'#!/usr/bin/env bash\nset -euo pipefail\nprintf "## Contexto visual\\n\\n![Captura](<%s>)\\n\\n" "$TEST_IMAGE"\nprintf "%s\\n" "### Texto detectado" ""\nprintf \'%s\\n\' \'```text\' \'OCR de prueba\' \'```\''
write_mock noctalia '#!/usr/bin/env bash
printf "%s\\n" "$*" >>"$TEST_NOCTALIA_LOG"
[[ -z "${TEST_REPLAY_PATH:-}" ]] || printf replay >"$TEST_REPLAY_PATH"'
write_mock hyprctl '#!/usr/bin/env bash
printf "%s\\n" "{\\\"title\\\":\\\"Editor\\\"}"'
mkdir -p "$test_root/replays"
capsule_dir=$(PATH="$test_root/bin:$PATH" HOME="$test_root/home" TEST_CLIPBOARD="$test_root/capsule-clipboard" TEST_WL_COPY_ARGS="$test_root/capsule-args" TEST_IMAGE="$test_root/screenshot.png" TEST_NOCTALIA_LOG="$test_root/noctalia.log" TEST_REPLAY_PATH="$test_root/replays/replay_auto.mp4" BUG_CAPSULE_REPLAY_DIR="$test_root/replays" "$capsule" --output-dir "$test_root/capsules")
[[ -f "$capsule_dir/README.md" && -f "$capsule_dir/metadata.md" && -f "$capsule_dir/capture.png" ]]
[[ $(stat -c '%a' "$test_root/capsules") == 700 ]]
[[ $(stat -c '%a' "$capsule_dir") == 700 ]]
[[ $(stat -c '%a' "$capsule_dir/README.md") == 600 ]]
[[ $(stat -c '%a' "$capsule_dir/metadata.md") == 600 ]]
[[ $(stat -c '%a' "$capsule_dir/capture.png") == 600 ]]
[[ -L "$capsule_dir/replay.mp4" ]]
[[ "$(readlink "$capsule_dir/replay.mp4")" == "$test_root/replays/replay_auto.mp4" ]]
grep -Fq '![Captura](<capture.png>)' "$capsule_dir/README.md"
grep -Fq 'OCR de prueba' "$capsule_dir/README.md"
grep -Fq 'plugin noctalia/screen_recorder:service all replay-save' "$test_root/noctalia.log"
cmp -s "$capsule_dir/README.md" "$test_root/capsule-clipboard"
grep -Fxq -- '--sensitive --paste-once' "$test_root/capsule-args"

without_replay=$(PATH="$test_root/bin:$PATH" HOME="$test_root/home" TEST_CLIPBOARD="$test_root/capsule-clipboard" TEST_IMAGE="$test_root/screenshot.png" BUG_CAPSULE_NOCTALIA=missing-command "$capsule" --output-dir "$test_root/capsules")
grep -Fq 'Replay: no disponible' "$without_replay/README.md"
printf stale >"$test_root/replays/replay_stale.mp4"
stale_capsule=$(PATH="$test_root/bin:$PATH" HOME="$test_root/home" TEST_CLIPBOARD="$test_root/capsule-clipboard" TEST_IMAGE="$test_root/screenshot.png" TEST_NOCTALIA_LOG="$test_root/noctalia.log" BUG_CAPSULE_REPLAY_DIR="$test_root/replays" BUG_CAPSULE_REPLAY_POLLS=1 "$capsule" --output-dir "$test_root/capsules")
grep -Fq 'Replay: no disponible' "$stale_capsule/README.md"
[[ ! -L "$stale_capsule/replay.mp4" ]]
printf '%s\n' 'PASS: capture-qr, media-convert y bug-capsule preservan datos locales y rutas únicas'
