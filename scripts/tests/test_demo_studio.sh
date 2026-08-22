#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/demo-studio"}
test_root=$(mktemp -d)
cleanup() { pkill -P "$$" 2>/dev/null || true; rm -rf -- "$test_root"; }
trap cleanup EXIT
mkdir -p "$test_root/bin" "$test_root/home" "$test_root/runtime" "$test_root/out"

write_mock() { printf '%s\n' "$2" >"$test_root/bin/$1"; chmod +x "$test_root/bin/$1"; }
write_mock notify-send '#!/usr/bin/env bash
printf "%s\\n" "$*" >>"$TEST_LOG"'
write_mock gpu-screen-recorder '#!/usr/bin/env bash
set -euo pipefail
output=
command_line="$*"
while (($#)); do
  [[ "$1" == -o ]] && { output=$2; shift 2; continue; }
  shift
done
printf "%s\\n" "$command_line" >>"$TEST_GSR_LOG"
exec -a gpu-screen-recorder python3 -c '"'"'import signal, sys
path = sys.argv[1]
def stop(_signal, _frame):
    open(path, "w", encoding="utf-8").write("video")
    raise SystemExit(0)
signal.signal(signal.SIGINT, stop)
signal.pause()
'"'"' "$output"'
write_mock mpv '#!/usr/bin/env bash
set -euo pipefail
printf "%s\\n" "$*" >>"$TEST_MPV_LOG"
trap "exit 0" TERM
while :; do sleep 1; done'
write_mock zenity '#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *"Audio de la grabación"*) printf "%s\\n" "Ambos" ;;
  *"¿Mostrar la webcam"*) exit 0 ;;
  *"Fuente de pantalla"*) printf "%s\\n" "Elegir mediante portal" ;;
esac'

base_env=(PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_RUNTIME_DIR="$test_root/runtime" DEMO_STUDIO_RECORDINGS_DIR="$test_root/out" TEST_LOG="$test_root/notify.log" TEST_MPV_LOG="$test_root/mpv.log" TEST_GSR_LOG="$test_root/gsr.log")

[[ $(env "${base_env[@]}" "$helper" status) == idle ]]
output=$(env "${base_env[@]}" DEMO_STUDIO_AUDIO=both DEMO_STUDIO_CAPTURE=portal DEMO_STUDIO_WEBCAM=true DEMO_STUDIO_WEBCAM_DEVICE=/dev/null "$helper" start)
[[ $(env "${base_env[@]}" "$helper" status) == recording ]]
state="$test_root/runtime/demo-studio/state"
grep -Fxq 'webcam=true' "$state"
grep -Fqx "output=$output" "$state"
grep -Fq -- '-w portal -c mp4 -s 1920x1080 -f 60 -k h264' "$test_root/gsr.log"
grep -Fq -- '--title=Demo Studio Webcam' "$test_root/mpv.log"
grep -Fq -- '--wayland-app-id=demo-studio-webcam' "$test_root/mpv.log"
env "${base_env[@]}" "$helper" stop >/dev/null
[[ $(env "${base_env[@]}" "$helper" status) == idle ]]
[[ -s "$output" ]]
grep -Fq "Archivo guardado: $output" "$test_root/notify.log"

show_output=$(env "${base_env[@]}" DEMO_STUDIO_WEBCAM_DEVICE=/dev/null "$helper" show)
grep -Fq -- '-a default_output|default_input' "$test_root/gsr.log"
env "${base_env[@]}" "$helper" stop >/dev/null
[[ -s "$show_output" ]]

dry_run=$(env "${base_env[@]}" DEMO_STUDIO_DRY_RUN=1 DEMO_STUDIO_AUDIO=both DEMO_STUDIO_CAPTURE=portal "$helper" start)
[[ "$dry_run" == *'DRY-RUN'* && "$dry_run" == *'-w portal'* && "$dry_run" == *'default_output\|default_input'* ]]
[[ $(env "${base_env[@]}" "$helper" status) == idle ]]

override=$(env "${base_env[@]}" DEMO_STUDIO_DRY_RUN=1 "$helper" start --resolution 2560x1440 --frame-rate 120)
[[ "$override" == *'-s 2560x1440'* && "$override" == *'-f 120'* ]] || {
  printf '%s\n' 'FAIL: Demo Studio no aplicó el override de resolución/frecuencia.' >&2
  exit 1
}

bash -c 'exec -a gpu-screen-recorder sleep 30' >/dev/null 2>&1 &
foreign=$!
set +e
env "${base_env[@]}" "$helper" start >/dev/null 2>&1
result=$?
set -e
kill -TERM "$foreign" 2>/dev/null || true
wait "$foreign" 2>/dev/null || true
[[ $result -ne 0 ]] || { printf '%s\n' 'FAIL: permitió una grabación normal ajena' >&2; exit 1; }

starts_before=$(wc -l <"$test_root/gsr.log")
env "${base_env[@]}" "$helper" start >"$test_root/start-one.out" 2>"$test_root/start-one.err" &
start_one=$!
env "${base_env[@]}" "$helper" start >"$test_root/start-two.out" 2>"$test_root/start-two.err" &
start_two=$!
set +e
wait "$start_one"; start_one_result=$?
wait "$start_two"; start_two_result=$?
set -e
(( (start_one_result == 0 && start_two_result != 0) || (start_one_result != 0 && start_two_result == 0) )) || {
  printf '%s\n' 'FAIL: dos inicios simultáneos no dejaron exactamente un resultado correcto' >&2
  exit 1
}
starts_after=$(wc -l <"$test_root/gsr.log")
[[ $((starts_after - starts_before)) -eq 1 ]] || {
  printf '%s\n' 'FAIL: dos inicios simultáneos lanzaron más de un grabador' >&2
  exit 1
}
[[ $(env "${base_env[@]}" "$helper" status) == recording ]]
recording_pid=$(awk -F= '$1 == "pid" { print $2; exit }' "$test_root/runtime/demo-studio/state")
env "${base_env[@]}" "$helper" stop >/dev/null
for _ in {1..40}; do
  kill -0 "$recording_pid" 2>/dev/null || break
  sleep 0.05
done
! kill -0 "$recording_pid" 2>/dev/null || { printf '%s\n' 'FAIL: dejó un grabador huérfano' >&2; exit 1; }
printf '%s\n' 'PASS: demo-studio guarda estado propio, serializa inicios y no deja grabadores huérfanos'
