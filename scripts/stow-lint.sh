#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
host_config=${1:-${DOTFILES_HOST_CONFIG:-}}
capabilities=${2:-${DOTFILES_CAPABILITIES_JSON:-}}
if [[ -z "$host_config" ]]; then
	default_host="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/host.toml"
	[[ -f "$default_host" ]] && host_config=$default_host
fi
runtime_root=${XDG_RUNTIME_DIR:-/tmp}
workspace="$(mktemp -d --tmpdir="$runtime_root" dotfiles-stow-lint.XXXXXX)"
target="$workspace/home"
config_root="$workspace/config"
state_root="$workspace/state"
test_runtime="$workspace/runtime"
mkdir -p "$target" "$config_root" "$state_root" "$test_runtime"
chmod 700 "$test_runtime"
cleanup() {
	[[ "$workspace" == "$runtime_root"/dotfiles-stow-lint.* ]] || return 1
	rm -rf -- "$workspace"
}
trap cleanup EXIT

if [[ -z "$capabilities" ]]; then
	capabilities="$workspace/capabilities.json"
	python3 "$repo_root/scripts/dotfiles_host.py" --repo "$repo_root" detect >"$capabilities"
fi

args=(--repo "$repo_root" resolve --safe-defaults)
[[ -n "$host_config" ]] && args+=(--host-config "$host_config")
args+=(--capabilities "$capabilities" --write)
plan_json="$workspace/plan.json"
HOME="$target" XDG_CONFIG_HOME="$config_root" XDG_STATE_HOME="$state_root" \
	python3 "$repo_root/scripts/dotfiles_host.py" "${args[@]}" >"$plan_json"
mapfile -t packages < <(python3 -c 'import json,sys; print(*json.load(open(sys.argv[1]))["modules"], sep="\n")' "$plan_json")
hypr_source="$repo_root/hypr-common/.config/hypr/hyprland.lua"
if [[ " ${packages[*]} " != *" hypr-common "* ]]; then
	printf 'El plan temporal no incluye hypr-common; no se puede validar Hyprland. Módulos: %s\n' \
		"${packages[*]:-(ninguno)}" >&2
	exit 2
fi
[[ -f "$hypr_source" ]] || {
	printf 'No existe la entrada Hyprland de hypr-common: %s\n' "$hypr_source" >&2
	exit 2
}
for package in "${packages[@]}"; do
	[[ -d "$repo_root/$package" ]] || { printf 'No existe el módulo: %s\n' "$package" >&2; exit 2; }
done

stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' \
	--simulate --verbose=1 --dir "$repo_root" --target "$target" "${packages[@]}"
stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' \
	--dir "$repo_root" --target "$target" "${packages[@]}"

hypr_config="$target/.config/hypr/hyprland.lua"
if [[ ! -f "$hypr_config" ]]; then
	printf 'Stow temporal no creó hyprland.lua: %s (fuente esperada: %s)\n' \
		"$hypr_config" "$hypr_source" >&2
	exit 2
fi
hypr_config_real="$(realpath -e -- "$hypr_config")"
hypr_source_real="$(realpath -e -- "$hypr_source")"
if [[ "$hypr_config_real" != "$hypr_source_real" ]]; then
	printf 'hyprland.lua temporal no apunta a hypr-common: %s -> %s (esperado: %s)\n' \
		"$hypr_config" "$hypr_config_real" "$hypr_source_real" >&2
	exit 2
fi
printf 'Hyprland temporal: %s -> %s\n' "$hypr_config" "$hypr_config_real"

require_validators=${DOTFILES_REQUIRE_RUNTIME_VALIDATORS:-0}
validate_or_defer() {
	local command=$1 label=$2
	shift 2
	if command -v "$command" >/dev/null 2>&1; then
		"$@"
	elif [[ "$require_validators" == 1 ]]; then
		printf 'Falta el validador requerido: %s (%s)\n' "$command" "$label" >&2
		return 1
	else
		printf 'AVISO: validación diferida hasta instalar %s (%s).\n' "$command" "$label" >&2
	fi
}

validator_env=(env HOME="$target" XDG_CONFIG_HOME="$config_root" XDG_STATE_HOME="$state_root" XDG_RUNTIME_DIR="$test_runtime")
validate_or_defer Hyprland Hyprland \
	"${validator_env[@]}" DOTFILES_DEPLOYED_HYPR_DIR="$target/.config/hypr" \
	DOTFILES_GENERATED_HYPR_DIR="$state_root/dotfiles/generated/hypr" \
	Hyprland --verify-config -c "$hypr_config"
validate_or_defer noctalia Noctalia \
	"${validator_env[@]}" noctalia config validate "$target/.config/noctalia"
validate_or_defer kanata Kanata \
	"${validator_env[@]}" kanata --check -c "$target/.config/kanata/config.kbd"
