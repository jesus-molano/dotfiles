#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly launcher=${1:-"$repo_root/gaming/.local/bin/gaming-launcher"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/state/gaming/benchmarks/demo/run-1"
printf '%s\n' 'fps,frametime' '60,16.6' >"$test_root/state/gaming/benchmarks/demo/run-1/MangoHud.csv"
printf '%s\n' 'Average FPS,1% Min FPS' '60,55' >"$test_root/state/gaming/benchmarks/demo/run-1/MangoHud_summary.csv"

printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >"$TEST_LOG"' >"$test_root/bin/uwsm"
chmod +x "$test_root/bin/uwsm"

entries=$(XDG_STATE_HOME="$test_root/state" "$launcher" list)
[[ "$entries" != *'Benchmark report — demo'* ]] || {
	printf '%s\n' 'FAIL: mostró un informe antes de tener tres CSV.' >&2
	exit 1
}

printf '%s\n' 'fps,frametime' '61,16.4' >"$test_root/state/gaming/benchmarks/demo/run-1/extra-1.csv"
printf '%s\n' 'fps,frametime' '62,16.1' >"$test_root/state/gaming/benchmarks/demo/run-1/extra-2.csv"
entries=$(XDG_STATE_HOME="$test_root/state" "$launcher" list)
[[ "$entries" != *'Benchmark report — demo'* ]] || {
	printf '%s\n' 'FAIL: contó tres CSV de un mismo directorio como tres ejecuciones.' >&2
	exit 1
}

for run in run-2 run-3; do
	mkdir -p "$test_root/state/gaming/benchmarks/demo/$run"
	printf '%s\n' 'fps,frametime' '60,16.6' >"$test_root/state/gaming/benchmarks/demo/$run/MangoHud.csv"
	printf '%s\n' 'Average FPS,1% Min FPS' '60,55' >"$test_root/state/gaming/benchmarks/demo/$run/MangoHud_summary.csv"
	if [[ $run == run-2 ]]; then
		entries=$(XDG_STATE_HOME="$test_root/state" "$launcher" list)
		[[ "$entries" != *'Benchmark report — demo'* ]] || {
			printf '%s\n' 'FAIL: contó los CSV summary como ejecuciones.' >&2
			exit 1
		}
	fi
done
entries=$(XDG_STATE_HOME="$test_root/state" "$launcher" list)
benchmark_selection=$(awk -F '\t' '$1 == "Benchmark report — demo" { print; exit }' <<<"$entries")
[[ "$benchmark_selection" == $'Benchmark report — demo\tOpen results from three or more runs' ]]
[[ "$entries" != *'report_demo'* && "$entries" != *'scx_manager'* ]]
PATH="$test_root/bin:$PATH" XDG_STATE_HOME="$test_root/state" TEST_LOG="$test_root/log" \
	"$launcher" run "$benchmark_selection"
grep -Fq 'app -- ghostty -e bash -lc' "$test_root/log"
grep -Fq 'bash demo' "$test_root/log"

if PATH="$test_root/bin:$PATH" XDG_STATE_HOME="$test_root/state" TEST_LOG="$test_root/log" \
	"$launcher" run 'report_../escape' >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: gaming-launcher aceptó un nombre con ruta.' >&2
	exit 1
fi

python3 - "$repo_root" <<'PY'
from pathlib import Path
import sys
import tomllib

root = Path(sys.argv[1])
with (root / "gaming/.config/noctalia/gaming.toml").open("rb") as source:
    entry = tomllib.load(source)["shell"]["launcher"]["dmenu"]["entry"]["games"]
assert entry["label"] == "Games"
assert entry["glyph"] == "device-gamepad-2"
assert entry["exec"] == 'gaming-launcher run "{selection}"'
PY

printf '%s\n' 'PASS: gaming-launcher espera tres ejecuciones y revalida el benchmark seleccionado'
