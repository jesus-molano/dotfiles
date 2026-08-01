#!/usr/bin/env bash
set -Eeuo pipefail

# Sincroniza exclusivamente las tres skills explícitas de Project Atlas y su
# sección MCP. No ejecuta git pull, no recompila Atlas y no toca otros MCP.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly DOTFILES_DIR
readonly PINNED_ATLAS_COMMIT="2cfc15d4c7508f1f3244cba5f12e3b1682d86529"
readonly PINNED_ATLAS_DIST_HASH="966e12105e64cd5b38f9fd2ca546fa2e1381551d59f1eb132e4118445affb63d"
readonly -a ATLAS_SKILLS=(frontend-task reuse-first visual-direction)

mode=check
atlas_root="${PROJECT_ATLAS_CHECKOUT:-$HOME/dev/project-atlas}"
skills_root="${CODEX_SKILLS_ROOT:-$HOME/.agents/skills}"
codex_config="${CODEX_HOME:-$HOME/.codex}/config.toml"

usage() {
	printf '%s\n' \
		'Uso: scripts/sync-project-atlas.sh [--check|--apply] [opciones]' \
		'' \
		'  --check                valida copia, instalación y MCP sin escribir (predeterminado)' \
		'  --apply                instala copias con backup y registra el MCP oficial' \
		'  --atlas-root RUTA      clon estable de Project Atlas' \
		'  --skills-root RUTA     destino de skills de Codex' \
		'  --codex-config RUTA    config.toml efectivo de Codex'
}

require_value() {
	local option=$1 value=${2:-}
	[[ -n "$value" && "$value" != -* ]] || {
		printf 'Falta un valor para %s.\n' "$option" >&2
		exit 2
	}
}

while (($#)); do
	case "$1" in
	--check)
		mode=check
		shift
		;;
	--apply)
		mode=apply
		shift
		;;
	--atlas-root)
		require_value "$1" "${2:-}"
		atlas_root=$2
		shift 2
		;;
	--skills-root)
		require_value "$1" "${2:-}"
		skills_root=$2
		shift 2
		;;
	--codex-config)
		require_value "$1" "${2:-}"
		codex_config=$2
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'Opción no reconocida: %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	esac
done

for command_name in awk diff find git node realpath sha256sum sort wc xargs; do
	command -v "$command_name" >/dev/null || {
		printf 'Falta el comando requerido: %s\n' "$command_name" >&2
		exit 1
	}
done

atlas_root="$(realpath -- "$atlas_root")"
skills_root="$(realpath -m -- "$skills_root")"
codex_config="$(realpath -m -- "$codex_config")"
readonly atlas_root skills_root codex_config

[[ "$atlas_root" != / && -d "$atlas_root/.git" ]] || {
	printf 'No es un clon Git válido de Project Atlas: %s\n' "$atlas_root" >&2
	exit 1
}

atlas_head="$(git -C "$atlas_root" rev-parse HEAD)"
[[ "$atlas_head" == "$PINNED_ATLAS_COMMIT" ]] || {
	printf 'El clon Atlas está en %s; los dotfiles fijan %s.\n' \
		"$atlas_head" "$PINNED_ATLAS_COMMIT" >&2
	printf '%s\n' 'Actualiza primero la copia vendorizada y su commit auditado.' >&2
	exit 1
}

[[ -z "$(git -C "$atlas_root" status --porcelain)" ]] || {
	printf 'El clon Atlas tiene cambios locales; no se usará como autoridad.\n' >&2
	exit 1
}

readonly vendored_root="$DOTFILES_DIR/codex/.agents/skills"
readonly atlas_installer="$atlas_root/frontend-codex-kit/install.sh"
readonly atlas_doctor="$atlas_root/frontend-codex-kit/doctor.sh"

for required_path in \
	"$atlas_installer" \
	"$atlas_doctor" \
	"$atlas_root/frontend-codex-kit/lib/kit-common.sh" \
	"$atlas_root/frontend-codex-kit/register-codex-mcp.mjs" \
	"$atlas_root/packages/mcp/dist/index.js"; do
	[[ -f "$required_path" ]] || {
		printf 'Falta un artefacto de Atlas: %s\n' "$required_path" >&2
		exit 1
	}
done

# dist/ está ignorado por el repositorio Atlas. Se fija la huella de todos los
# artefactos JavaScript first-party antes de ejecutar el smoke o registrar MCP.
dist_file_count="$(
	cd -- "$atlas_root"
	find packages -path '*/dist/*.js' -type f | wc -l
)"
[[ "$dist_file_count" -gt 0 ]] || {
	printf 'Atlas no contiene artefactos JavaScript compilados.\n' >&2
	exit 1
}
atlas_dist_hash="$(
	(
		cd -- "$atlas_root"
		find packages -path '*/dist/*.js' -type f -print0 \
			| sort -z \
			| xargs -0 sha256sum
	) | sha256sum | awk '{ print $1 }'
)"
[[ "$atlas_dist_hash" == "$PINNED_ATLAS_DIST_HASH" ]] || {
	printf 'El build local de Atlas no coincide con la huella auditada.\n' >&2
	printf 'Esperada: %s\nActual:   %s\n' \
		"$PINNED_ATLAS_DIST_HASH" "$atlas_dist_hash" >&2
	printf '%s\n' 'Recompila desde el commit fijado y audita la nueva huella antes de usarlo.' >&2
	exit 1
}

for skill in "${ATLAS_SKILLS[@]}"; do
	source_skill="$atlas_root/skills/$skill"
	vendored_skill="$vendored_root/$skill"
	[[ -f "$vendored_skill/SKILL.md" ]] || {
		printf 'Falta la skill vendorizada: %s\n' "$vendored_skill" >&2
		exit 1
	}
	if ! diff --brief --recursive --no-dereference \
		"$source_skill" "$vendored_skill" >/dev/null; then
		printf 'La copia vendorizada no coincide con Atlas: %s\n' "$skill" >&2
		diff --brief --recursive --no-dereference \
			"$source_skill" "$vendored_skill" >&2 || true
		exit 1
	fi
done

if [[ "$mode" == check ]]; then
	printf 'Copia vendorizada: %s (%s)\n' "$vendored_root" "$PINNED_ATLAS_COMMIT"
	exec bash "$atlas_doctor" \
		--atlas-root "$atlas_root" \
		--codex-skills-root "$skills_root" \
		--codex-config-path "$codex_config"
fi

printf 'Destino exacto de skills: %s\n' "$skills_root"
printf 'Sección MCP exacta: [mcp_servers.component-atlas] en %s\n' "$codex_config"

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/project-atlas"
mkdir -p -- "$state_root/backups"
backup_root="$(mktemp -d -- "$state_root/backups/sync-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
chmod 700 "$backup_root"
mkdir -p -- "$backup_root/skills"
config_existed=0
config_touched=0
rollback_active=1
declare -A skill_touched=()

rollback() {
	local trapped_status=$?
	local status=${1:-$trapped_status}
	((status != 0)) || status=1
	trap - ERR INT TERM
	if ((rollback_active)); then
		# ERR puede heredarse en subshells con `set -E`. Este directorio funciona
		# como cerrojo compartido para que una restauración nunca se ejecute dos veces.
		if ! mkdir -- "$backup_root/.rollback-started" 2>/dev/null; then
			exit "$status"
		fi
		printf 'Falló la sincronización; restaurando destinos previos.\n' >&2
		mkdir -p -- "$backup_root/failed/skills"
		local skill target previous
		for skill in "${ATLAS_SKILLS[@]}"; do
			[[ "${skill_touched[$skill]:-0}" == 1 ]] || continue
			target="$skills_root/$skill"
			previous="$backup_root/skills/$skill"
			if [[ -e "$target" || -L "$target" ]]; then
				mv -- "$target" "$backup_root/failed/skills/$skill"
			fi
			if [[ -e "$previous" || -L "$previous" ]]; then
				mv -- "$previous" "$target"
			fi
		done
		if ((config_touched && config_existed)); then
			mkdir -p -- "$backup_root/failed/config"
			if [[ -e "$codex_config" || -L "$codex_config" ]]; then
				mv -- "$codex_config" "$backup_root/failed/config/config.toml"
			fi
			mkdir -p -- "$(dirname -- "$codex_config")"
			cp -a -- "$backup_root/config.toml" "$codex_config"
		elif ((config_touched)) && [[ -e "$codex_config" || -L "$codex_config" ]]; then
			mkdir -p -- "$backup_root/failed/config"
			mv -- "$codex_config" "$backup_root/failed/config/config.toml"
		fi
		printf 'Backup y restos recuperables: %s\n' "$backup_root" >&2
	fi
	exit "$status"
}
trap rollback ERR INT TERM

mkdir -p -- "$skills_root"
if [[ -e "$codex_config" || -L "$codex_config" ]]; then
	config_existed=1
	cp -a -- "$codex_config" "$backup_root/config.toml"
fi

for skill in "${ATLAS_SKILLS[@]}"; do
	target="$skills_root/$skill"
	if [[ -e "$target" || -L "$target" ]]; then
		mv -- "$target" "$backup_root/skills/$skill"
	fi
	skill_touched["$skill"]=1
	cp -a -- "$vendored_root/$skill" "$target"
done

# El helper oficial conserva todas las demás secciones y crea además su propio
# backup cuando necesita actualizar este único bloque.
# shellcheck source=/dev/null
source "$atlas_root/frontend-codex-kit/lib/kit-common.sh"
stable_node_file="$backup_root/stable-node"
if atlas_resolve_stable_node >"$stable_node_file"; then
	IFS= read -r stable_node <"$stable_node_file"
else
	status=$?
	rollback "$status"
fi
[[ -n "$stable_node" ]] || rollback 1
config_touched=1
"$stable_node" "$atlas_root/frontend-codex-kit/register-codex-mcp.mjs" \
	--config "$codex_config" \
	--node "$stable_node" \
	--entry "$atlas_root/packages/mcp/dist/index.js" \
	--force

bash "$atlas_doctor" \
	--atlas-root "$atlas_root" \
	--codex-skills-root "$skills_root" \
	--codex-config-path "$codex_config"

rollback_active=0
trap - ERR INT TERM
printf '%s\n' "$backup_root" >"$state_root/last-backup"
printf 'Project Atlas sincronizado y validado. Backup: %s\n' "$backup_root"
