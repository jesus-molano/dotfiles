#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/appearance-switch"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/state" "$test_root/asset-store" \
	"$test_root/wallpapers/atlas" "$test_root/wallpapers/dracula" \
	"$test_root/wallpapers/catppuccin" "$test_root/wallpapers/nord"
touch "$test_root/asset-store/atlas-default.png"
ln -s "$test_root/asset-store/atlas-default.png" "$test_root/wallpapers/atlas/default.png"
touch "$test_root/wallpapers/atlas/alternate.jpg" \
	"$test_root/wallpapers/dracula/default.png" "$test_root/wallpapers/dracula/alternate.webp" \
	"$test_root/wallpapers/catppuccin/default.png" "$test_root/wallpapers/catppuccin/alternate.jpg" \
	"$test_root/wallpapers/nord/alternate.png"

cat >"$test_root/catalog.tsv" <<EOF
# id	label	palette_source	palette_name	wallpaper_expected
atlas	Atlas	custom	ProjectAtlas	~/wallpapers/atlas/default.png
dracula	Dracula	builtin	Dracula	~/wallpapers/dracula/default.png
catppuccin	Catppuccin	builtin	Catppuccin	~/wallpapers/catppuccin/default.png
nord	Nord	builtin	Nord	~/wallpapers/nord/missing.png
EOF

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
visible=$(readlink -f -- "$TEST_VISIBLE" 2>/dev/null || true)
advance_pending() {
	local pending=$1 live=$2 count=0
	local count_file="$pending.count"
	[[ -f $pending ]] || return 0
	[[ -r $count_file ]] && IFS= read -r count <"$count_file"
	count=$((count + 1))
	if ((count >= 3)); then
		mv -f -- "$pending" "$live"
		rm -f -- "$count_file"
	else
		printf '%s\n' "$count" >"$count_file"
	fi
}
case "$1 $2" in
'msg color-scheme-set')
	printf 'palette:%s:%s:visible=%s\n' "$3" "$4" "$visible" >>"$TEST_LOG"
	[[ ${TEST_FAIL:-} != palette ]] || exit 1
	if [[ ${TEST_ASYNC:-0} == 1 ]]; then
		printf '%s %s\n' "$3" "$4" >"$TEST_SCHEME_FILE.pending"
	else
		printf '%s %s\n' "$3" "$4" >"$TEST_SCHEME_FILE"
	fi
	;;
'msg color-scheme-get')
	advance_pending "$TEST_SCHEME_FILE.pending" "$TEST_SCHEME_FILE"
	if [[ -n ${TEST_SCHEME:-} ]]; then
		printf '%s\n' "$TEST_SCHEME"
	elif [[ -r $TEST_SCHEME_FILE ]]; then
		cat "$TEST_SCHEME_FILE"
	else
		printf '%s\n' 'custom ProjectAtlas'
	fi
	;;
'msg wallpaper-get')
	advance_pending "$TEST_WALLPAPER_FILE.pending" "$TEST_WALLPAPER_FILE"
	if [[ -n ${TEST_CURRENT_WALLPAPER:-} ]]; then
		printf '%s\n' "$TEST_CURRENT_WALLPAPER"
	elif [[ -r $TEST_WALLPAPER_FILE ]]; then
		cat "$TEST_WALLPAPER_FILE"
	else
		printf '%s\n' "$TEST_ROOT/wallpapers/atlas/default.png"
	fi
	;;
'msg wallpaper-set')
	printf 'wallpaper:%s:visible=%s\n' "$3" "$visible" >>"$TEST_LOG"
	[[ ${TEST_FAIL:-} != wallpaper ]] || exit 1
	if [[ ${TEST_ASYNC:-0} == 1 ]]; then
		printf '%s\n' "$3" >"$TEST_WALLPAPER_FILE.pending"
	else
		printf '%s\n' "$3" >"$TEST_WALLPAPER_FILE"
	fi
	;;
'msg templates-apply')
	printf 'templates:visible=%s\n' "$visible" >>"$TEST_LOG"
	[[ ${TEST_FAIL:-} != templates ]] || exit 1
	case "$(cat "$TEST_SCHEME_FILE")" in
	'custom ProjectAtlas') rendered_id=atlas ;;
	'builtin Dracula') rendered_id=dracula ;;
	'builtin Catppuccin') rendered_id=catppuccin ;;
	'builtin Nord') rendered_id=nord ;;
	*) exit 3 ;;
	esac
	printf '%s\n' "$rendered_id" >"$TEST_RENDERED_ID_FILE"
	;;
*) printf 'Noctalia inesperado: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
chmod +x "$test_root/bin/noctalia"

readonly visible="$test_root/state/dotfiles/appearance-switch/visible"
run() {
	PATH="$test_root/bin:$PATH" HOME="$test_root" APPEARANCE_CATALOG="$test_root/catalog.tsv" \
		APPEARANCE_WALLPAPER_ROOT="$test_root/wallpapers" XDG_STATE_HOME="$test_root/state" \
		APPEARANCE_LOCK_TIMEOUT="${TEST_LOCK_TIMEOUT:-0.1}" APPEARANCE_APPLY_TIMEOUT=2 \
		TEST_VISIBLE="$visible" TEST_LOG="$test_root/log" \
		TEST_ROOT="$test_root" TEST_SCHEME_FILE="$test_root/scheme" \
		TEST_WALLPAPER_FILE="$test_root/wallpaper" \
		TEST_RENDERED_ID_FILE="$test_root/state/dotfiles/appearance-switch/rendered" \
		"$helper" "$@"
}

[[ $(run list) == $'atlas\tAtlas\tcustom ProjectAtlas\ndracula\tDracula\tbuiltin Dracula\ncatppuccin\tCatppuccin\tbuiltin Catppuccin\nnord\tNord\tbuiltin Nord' ]]
[[ $(run current) == atlas ]]
[[ $(run prepare) == atlas ]]
[[ $(readlink -f -- "$visible") == "$test_root/wallpapers/atlas" ]]

[[ $(run apply atlas) == atlas ]]
[[ $(<"$test_root/state/dotfiles/appearance-switch/current") == atlas ]]
[[ $(<"$test_root/log") == \
	$'palette:custom:ProjectAtlas:visible='"$test_root"$'/wallpapers/atlas\nwallpaper:'"$test_root"$'/wallpapers/atlas/default.png:visible='"$test_root"$'/wallpapers/atlas\ntemplates:visible='"$test_root"$'/wallpapers/atlas' ]]

[[ $(run next) == dracula ]]
[[ $(<"$test_root/state/dotfiles/appearance-switch/current") == dracula ]]
[[ $(readlink -f -- "$visible") == "$test_root/wallpapers/dracula" ]]
[[ $(run previous) == atlas ]]
[[ $(readlink -f -- "$visible") == "$test_root/wallpapers/atlas" ]]

# Recuerda el último fondo elegido con `/wall` y lo restaura al volver al tema.
printf '%s\n' "$visible/alternate.jpg" >"$test_root/wallpaper"
[[ $(TEST_ASYNC=1 run apply dracula) == dracula ]]
[[ $(<"$test_root/state/dotfiles/appearance-switch/last/atlas") == alternate.jpg ]]
[[ $(run apply atlas) == atlas ]]
[[ $(<"$test_root/wallpaper") == "$test_root/wallpapers/atlas/alternate.jpg" ]]

# Dos rotaciones rápidas esperan el lock y avanzan dos posiciones, no repiten.
TEST_ASYNC=1 TEST_LOCK_TIMEOUT=3 run next >"$test_root/next-1" &
next_pid_1=$!
TEST_ASYNC=1 TEST_LOCK_TIMEOUT=3 run next >"$test_root/next-2" &
next_pid_2=$!
wait "$next_pid_1" "$next_pid_2"
[[ $(<"$test_root/state/dotfiles/appearance-switch/current") == catppuccin ]]
[[ $(<"$test_root/scheme") == 'builtin Catppuccin' ]]
[[ $(run apply atlas) == atlas ]]

# Si desaparece el default configurado, usa el primer raster disponible. Esto
# permite editar las carpetas de fondos sin romper la rotación de temas.
[[ $(run apply nord) == nord ]]
[[ $(<"$test_root/wallpaper") == "$test_root/wallpapers/nord/alternate.png" ]]
[[ $(run apply atlas) == atlas ]]

# Un fallo de Noctalia restaura el conjunto visible y no cambia el estado propio.
if TEST_FAIL=wallpaper run apply dracula >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: ignoró el fallo de wallpaper-set.' >&2
	exit 1
fi
[[ $(<"$test_root/state/dotfiles/appearance-switch/current") == atlas ]]
[[ $(readlink -f -- "$visible") == "$test_root/wallpapers/atlas" ]]

# La simulación muestra el conjunto que usaría sin tocar el enlace ni el estado.
dry_run=$(run --dry-run apply dracula)
[[ $dry_run == *"visible $visible -> $test_root/wallpapers/dracula"* ]]
[[ $dry_run == *'color-scheme-set builtin Dracula'* ]]
[[ $dry_run == *'wallpaper-set'* ]]
[[ $(<"$test_root/state/dotfiles/appearance-switch/current") == atlas ]]
[[ $(readlink -f -- "$visible") == "$test_root/wallpapers/atlas" ]]

[[ $(TEST_SCHEME='builtin Dracula' run current) == dracula ]]
if TEST_SCHEME='custom Unknown' run current >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: una paleta viva desconocida reutilizó estado obsoleto.' >&2
	exit 1
fi

rm -f -- "$test_root/state/dotfiles/appearance-switch/rendered"
run template-ready
[[ $(<"$test_root/state/dotfiles/appearance-switch/rendered") == atlas ]]

if run apply '../dracula' >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: aceptó un ID con ruta.' >&2
	exit 1
fi
if run apply unknown >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: aceptó un ID desconocido.' >&2
	exit 1
fi

# El bloqueo compartido evita que dos cambios se intercalen.
exec 8>"$test_root/state/dotfiles/appearance-switch/lock"
flock 8
if run apply dracula >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: no respetó el bloqueo de apariencia.' >&2
	exit 1
fi
flock -u 8

python3 - "$repo_root" <<'PY'
import csv
import json
from pathlib import Path
import re
import sys
import tomllib

root = Path(sys.argv[1])
asset_root = root / 'noctalia/.local/share/wallpapers/noctalia-themes'
catalog_path = root / 'noctalia/.config/noctalia/appearances/catalog.tsv'
config_path = root / 'noctalia/.config/noctalia/config.toml'
sources_path = asset_root / 'SOURCES.md'
with catalog_path.open(encoding='utf-8', newline='') as source:
    catalog = [row for row in csv.reader(source, delimiter='\t') if row and not row[0].startswith('#')]
with config_path.open('rb') as source:
    config = tomllib.load(source)
wallpaper_config = config['wallpaper']
ready_template = config['theme']['templates']['user']['appearance_ready']
assert ready_template['index'] == 10000
assert ready_template['output_path'] == '$XDG_STATE_HOME/dotfiles/appearance-switch/rendered-theme.json'
assert ready_template['post_hook'].endswith('/appearance-switch template-ready')
assert (root / 'noctalia/.config/noctalia/templates/appearance-ready.json').is_file()

assert wallpaper_config['directory'].endswith('/.local/state/dotfiles/appearance-switch/visible')
assert len(catalog) == 7
assert 'favorite' not in wallpaper_config

with (root / 'noctalia/.config/noctalia/palettes/ObsidianAmber.json').open(encoding='utf-8') as source:
    obsidian_amber = json.load(source)['dark']
assert obsidian_amber['mPrimary'] == '#ffc857'
assert obsidian_amber['mSecondary'] == '#ff9f1c'
assert obsidian_amber['mSurface'] == '#0a0907'
assert obsidian_amber['terminal']['background'] == '#070604'

for scene_id, _label, palette_source, palette_name, wallpaper in catalog:
    theme_dir = asset_root / scene_id
    assert wallpaper == '-', f'{scene_id}: el default debe resolverse desde la carpeta'
    rasters = [path for path in theme_dir.iterdir() if path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp'}]
    assert len(rasters) >= 3, f'{scene_id}: esperaba al menos 3 fondos, hay {len(rasters)}'

actual_assets = {
    str(path.relative_to(asset_root))
    for path in asset_root.glob('*/*')
    if path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp'}
}
scene_pattern = '|'.join(re.escape(row[0]) for row in catalog)
documented_assets = set(re.findall(
    rf'`((?:{scene_pattern})/[^`]+\.(?:png|jpe?g|webp))`',
    sources_path.read_text(encoding='utf-8'),
    flags=re.IGNORECASE,
))
assert documented_assets == actual_assets, (
    f'fuentes desincronizadas: faltan={actual_assets - documented_assets}, '
    f'sobran={documented_assets - actual_assets}'
)

PY

printf '%s\n' 'PASS: colecciones, último fondo, espera asíncrona, bloqueo y rollback de enlace'
