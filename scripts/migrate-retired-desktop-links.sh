#!/usr/bin/env bash
set -euo pipefail

usage() { printf '%s\n' 'Uso: migrate-retired-desktop-links.sh {--check|--apply}'; }

mode=${1:-}
[[ "$mode" == --check || "$mode" == --apply ]] || { usage >&2; exit 2; }

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

readonly -a retired_links=(
	'hypr-common|.local/bin/dev-pulse-status'
	'noctalia|.local/share/noctalia/plugins/dev-pulse/plugin.toml'
	'noctalia|.local/share/noctalia/plugins/dev-pulse/service.luau'
	'noctalia|.local/share/noctalia/plugins/dev-pulse/widget.luau'
	'noctalia|.local/share/wallpapers/project-atlas/dracula-violet.png'
	'noctalia|.local/share/wallpapers/project-atlas/dracula-violet.svg'
	'noctalia|.local/share/wallpapers/project-atlas/nord-night.png'
	'noctalia|.local/share/wallpapers/project-atlas/nord-night.svg'
	'noctalia|.local/share/wallpapers/project-atlas/tokyo-night-city.png'
	'noctalia|.local/share/wallpapers/project-atlas/tokyo-night-city.svg'
)

# La primera versión de las colecciones usó project-atlas como raíz común.
# Project Atlas es ahora solo una apariencia. Retira únicamente enlaces que
# todavía pertenecen a esa raíz antigua del checkout y conserva cualquier
# archivo o enlace ajeno que el usuario haya colocado allí.
readonly retired_wallpaper_tree='.local/share/wallpapers/project-atlas'
readonly retired_wallpaper_source="$repo_root/noctalia/$retired_wallpaper_tree"
readonly managed_wallpaper_tree='.local/share/wallpapers/noctalia-themes'
readonly managed_wallpaper_source="$repo_root/noctalia/$managed_wallpaper_tree"

found=0
for specification in "${retired_links[@]}"; do
	module=${specification%%|*}
	relative=${specification#*|}
	target="$HOME/$relative"
	[[ -L "$target" ]] || continue
	link=$(readlink -- "$target")
	if [[ "$link" == /* ]]; then
		resolved=$(realpath -m -- "$link")
	else
		resolved=$(realpath -m -- "$(dirname -- "$target")/$link")
	fi
	expected="$repo_root/$module/$relative"
	[[ "$resolved" == "$expected" ]] || continue
	found=$((found + 1))
	if [[ "$mode" == --apply ]]; then
		unlink -- "$target"
		printf 'REMOVED: %s\n' "$target"
	else
		printf 'RETIRED: %s\n' "$target"
	fi
done

retired_tree="$HOME/$retired_wallpaper_tree"
if [[ -d "$retired_tree" ]]; then
	while IFS= read -r -d '' target; do
		link=$(readlink -- "$target")
		if [[ "$link" == /* ]]; then
			resolved=$(realpath -m -- "$link")
		else
			resolved=$(realpath -m -- "$(dirname -- "$target")/$link")
		fi
		[[ "$resolved" == "$retired_wallpaper_source"/* ]] || continue
		found=$((found + 1))
		if [[ "$mode" == --apply ]]; then
			unlink -- "$target"
			printf 'REMOVED: %s\n' "$target"
		else
			printf 'RETIRED: %s\n' "$target"
		fi
	done < <(find "$retired_tree" -type l -print0)

	if [[ "$mode" == --apply ]]; then
		while IFS= read -r -d '' directory; do
			rmdir -- "$directory" 2>/dev/null || true
		done < <(find "$retired_tree" -depth -type d -print0)
	fi
fi

# Stow no conoce archivos que se retiraron de una carpeta entre despliegues.
# Limpia solo sus enlaces rotos y deja intactos los enlaces válidos o ajenos.
managed_tree="$HOME/$managed_wallpaper_tree"
if [[ -d "$managed_tree" ]]; then
	while IFS= read -r -d '' target; do
		[[ ! -e "$target" ]] || continue
		link=$(readlink -- "$target")
		if [[ "$link" == /* ]]; then
			resolved=$(realpath -m -- "$link")
		else
			resolved=$(realpath -m -- "$(dirname -- "$target")/$link")
		fi
		[[ "$resolved" == "$managed_wallpaper_source"/* ]] || continue
		found=$((found + 1))
		if [[ "$mode" == --apply ]]; then
			unlink -- "$target"
			printf 'REMOVED: %s\n' "$target"
		else
			printf 'RETIRED: %s\n' "$target"
		fi
	done < <(find "$managed_tree" -type l -print0)
fi

if ((found == 0)); then
	printf '%s\n' 'No hay enlaces retirados del desktop.'
fi
