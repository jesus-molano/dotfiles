#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly report=${1:-"$repo_root/gaming-tools/.local/bin/game-bench-report"}
test_root=$(mktemp -d)
cleanup() { rm -rf -- "$test_root"; }
trap cleanup EXIT

benchmark_root="$test_root/state/gaming/benchmarks/hades"
for run in run-1 run-2 run-3; do
	mkdir -p "$benchmark_root/$run"
	case "$run" in
	run-1) metadata=$'os,cpu,gpu,ram,kernel,driver,cpuscheduler\nCachyOS,CPU,GPU,32768,6.x,driver,performance'; header='fps,frametime,gpu_load'; normal='120,8.333,88'; slow='50,20.0,92' ;;
	run-2) metadata=$'os;cpu;gpu;ram;kernel;driver;cpuscheduler\nCachyOS;CPU;GPU;32768;6.x;driver;performance'; header='FPS;Frametime (ms);gpu_load'; normal='120;8,333;88'; slow='50;20,0;92' ;;
	run-3) metadata=$'os\tcpu\tgpu\tram\tkernel\tdriver\tcpuscheduler\nCachyOS\tCPU\tGPU\t32768\t6.x\tdriver\tperformance'; header=$'framerate\tframe_time\tgpu_load'; normal=$'120\t8.333\t88'; slow=$'50\t20.0\t92' ;;
	esac
	{
		printf '%s\n' "$metadata"
		printf '%s\n' "$header"
		for frame in {1..120}; do
			if ((frame % 30 == 0)); then printf '%s\n' "$slow"; else printf '%s\n' "$normal"; fi
		done
	} >"$benchmark_root/$run/MangoHud.csv"
	printf '%s\n' 'Average FPS,1% Min FPS' '100,50' >"$benchmark_root/$run/MangoHud_summary.csv"
	printf '%s\n' 'kernel=6.18.3-2-cachyos' 'gpu_driver=NVIDIA 580.12.01' 'composition=resolved' >"$benchmark_root/$run/metadata.txt"
done

human_output=$(XDG_STATE_HOME="$test_root/state" "$report" hades)
[[ "$human_output" == *'Ejecuciones válidas: 3; CSV válidos: 3 de 3'* ]]
[[ "$human_output" == *'mediana FPS: 120.00'* ]]
[[ "$human_output" == *'1% low: 50.00 FPS'* ]]
[[ "$human_output" == *'Kernel: 6.18.3-2-cachyos'* ]]
[[ "$human_output" == *'Driver: NVIDIA 580.12.01'* ]]
[[ "$human_output" == *'Composición: resolved'* ]]

json_output=$(XDG_STATE_HOME="$test_root/state" "$report" --json hades)
JSON_OUTPUT="$json_output" python3 - <<'PY'
import json
import os

report = json.loads(os.environ['JSON_OUTPUT'])
assert report['aggregate']['runs'] == 3
assert report['aggregate']['csv_files'] == 3
assert report['aggregate']['samples'] == 360
assert report['aggregate']['median_fps'] > 119
assert report['aggregate']['one_percent_low_fps'] == 50
assert report['metadata']['composition'] == ['resolved']
PY

mkdir -p "$benchmark_root/invalid"
printf '%s\n' 'cpu_temp,gpu_temp' '50,60' >"$benchmark_root/invalid/broken.csv"
XDG_STATE_HOME="$test_root/state" "$report" hades >/dev/null 2>"$test_root/warnings"
grep -q 'se omitió' "$test_root/warnings"

single_root="$test_root/state/gaming/benchmarks/single/run-1"
mkdir -p "$single_root"
for index in 1 2 3; do
	cp "$benchmark_root/run-1/MangoHud.csv" "$single_root/MangoHud-$index.csv"
done
if XDG_STATE_HOME="$test_root/state" "$report" single >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: tres CSV de una sola ejecución habilitaron el informe.' >&2
	exit 1
fi

printf '%s\n' 'PASS: game-bench-report analiza CSV, metadata y JSON'
