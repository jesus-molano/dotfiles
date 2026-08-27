#!/usr/bin/env bash
set -euo pipefail

# Bootstrap reproducible para CachyOS/Noctalia.
# No despliega system-etc ni cambia explícitamente GPU, arranque o almacenamiento.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR
readonly PACKAGES_CSV="$DOTFILES_DIR/packages.csv"
readonly FLATPAKS_CSV="$DOTFILES_DIR/flatpaks.csv"
readonly FLATPAK_REMOTES_CSV="$DOTFILES_DIR/flatpak-remotes.csv"
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
readonly HOST_TOOL="$DOTFILES_DIR/scripts/dotfiles_host.py"
declare -a PLAN_MODULES=()
declare -a PACKAGE_SCOPES=()
PLAN_JSON=''
CAPABILITIES_JSON=''
HOST_CONFIG=''
SAFE_DEFAULTS=0
BACKUP_DIR=''
MIGRATION_DIR=''
declare -a LEGACY_MODULES=()

CHECK_ONLY=0
LIST_PACKAGES=0

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[AVISO]\033[0m %s\n' "$*"; }
die() {
	printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
	exit 1
}

validate_xdg_config_layout() {
	local home_root=${HOME%/}
	local config_root=${XDG_CONFIG_HOME:-"$home_root/.config"}
	config_root=${config_root%/}
	[[ "$config_root" == "$home_root/.config" ]] ||
		die "XDG_CONFIG_HOME personalizado no está soportado por los módulos Stow: $config_root (esperado: $home_root/.config)."
}

usage() {
	cat <<'EOF'
Uso:
  ./install.sh [--host-config RUTA] [--safe-defaults] [--check|--list-packages]

  --host-config RUTA
               configuración local (por defecto: XDG_CONFIG_HOME/dotfiles/host.toml)
  --safe-defaults
               permite una composición base segura cuando no existe host.toml
  --check      valida manifiestos/paquetes y simula Stow sin modificar el sistema ni HOME
  --list-packages
               lista un paquete o app ID por línea sin modificar el sistema ni HOME

Los módulos de system-etc se gestionan aparte con just check-system/apply-system.
EOF
}

legacy_link_matches() {
	local module=$1 relative=$2 target source resolved
	target="$HOME/$relative"
	source="$DOTFILES_DIR/$module/$relative"
	[[ -f "$source" && -L "$target" ]] || return 1
	resolved="$(readlink -f -- "$target" 2>/dev/null || true)"
	[[ "$resolved" == "$source" ]]
}

legacy_fixture_for_host() {
	local fixture=''
	if legacy_link_matches hypr-desktop .config/hypr/config/monitors.lua &&
		legacy_link_matches hypr-desktop .config/hypr/config/user-inputs.lua &&
		legacy_link_matches gaming .local/bin/game-run &&
		legacy_link_matches backup .local/bin/desktop-backup &&
		legacy_link_matches qmd .config/qmd/index.yml; then
		fixture="$DOTFILES_DIR/scripts/tests/fixtures/current-host.toml"
	elif legacy_link_matches hypr-laptop .config/hypr/config/monitors.lua &&
		legacy_link_matches hypr-laptop .config/hypr/config/inputs.lua &&
		legacy_link_matches hypr-laptop .config/hypr/config/user-inputs.lua; then
		fixture="$DOTFILES_DIR/scripts/tests/fixtures/laptop-host.toml"
	fi
	[[ -n "$fixture" && -f "$fixture" ]] || return 1
	printf '%s\n' "$fixture"
}

seed_exact_legacy_host() {
	local destination=$1 fixture
	fixture="$(legacy_fixture_for_host)" || return 1
	install -d -m 700 -- "$(dirname "$destination")"
	install -m 600 -- "$fixture" "$destination"
	info "Elecciones del despliegue heredado guardadas en $destination"
}

parse_args() {
	while (($#)); do
		case "$1" in
		--host-config)
			(($# >= 2)) || die 'Falta la ruta de --host-config.'
			HOST_CONFIG=$2
			shift
			;;
		--safe-defaults) SAFE_DEFAULTS=1 ;;
		--check)
			CHECK_ONLY=1
			;;
		--list-packages)
			LIST_PACKAGES=1
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			die "Argumento no reconocido: $1"
			;;
		esac
		shift
	done

	if ((CHECK_ONLY && LIST_PACKAGES)); then
		die "--check y --list-packages no se pueden combinar."
	fi
	[[ -x "$HOST_TOOL" || -f "$HOST_TOOL" ]] || die "No existe el resolutor: $HOST_TOOL"
	python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 11))' || die 'Se requiere Python 3.11 o superior.'
	local default_host="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/host.toml"
	if [[ -z "$HOST_CONFIG" && ! -f "$default_host" ]]; then
		if ((CHECK_ONLY || LIST_PACKAGES)); then
			# Los modos de inspección pueden simular la equivalencia legacy, pero
			# nunca crean host.toml ni otro archivo bajo HOME/XDG.
			HOST_CONFIG="$(legacy_fixture_for_host || :)"
		else
			seed_exact_legacy_host "$default_host" || :
		fi
	fi
	if [[ -z "$HOST_CONFIG" && ! -f "$default_host" ]]; then
		if ((CHECK_ONLY || LIST_PACKAGES)); then
			warn 'No existe host.toml; se valida la base segura y quedan elecciones pendientes.'
			SAFE_DEFAULTS=1
		elif [[ -t 0 && -t 1 ]]; then
			info 'Primera instalación: se abrirá el asistente breve de composición.'
		python3 "$HOST_TOOL" --repo "$DOTFILES_DIR" configure --interactive >/dev/null
		else
			die 'Falta host.toml en una ejecución no interactiva. Usa --host-config o --safe-defaults.'
		fi
	fi
	PLAN_JSON="$(mktemp "${TMPDIR:-/tmp}/dotfiles-plan.XXXXXX")"
	CAPABILITIES_JSON="$(mktemp "${TMPDIR:-/tmp}/dotfiles-capabilities.XXXXXX")"
	trap 'rm -f -- "$PLAN_JSON" "$CAPABILITIES_JSON"' EXIT
	if ((CHECK_ONLY || LIST_PACKAGES)); then
		python3 "$HOST_TOOL" --repo "$DOTFILES_DIR" detect >"$CAPABILITIES_JSON" || die 'No se pudo detectar el hardware de forma segura.'
	else
		python3 "$HOST_TOOL" --repo "$DOTFILES_DIR" detect --write >"$CAPABILITIES_JSON" || die 'No se pudo detectar y guardar el hardware local.'
	fi
	local -a resolver=(python3 "$HOST_TOOL" --repo "$DOTFILES_DIR" resolve)
	[[ -n "$HOST_CONFIG" ]] && resolver+=(--host-config "$HOST_CONFIG")
	resolver+=(--capabilities "$CAPABILITIES_JSON")
	((SAFE_DEFAULTS)) && resolver+=(--safe-defaults)
	"${resolver[@]}" >"$PLAN_JSON" || die 'No se pudo resolver la composición local. Ejecuta dotf host configure o usa --safe-defaults.'
	mapfile -t PLAN_MODULES < <(python3 -c 'import json,sys; print(*json.load(open(sys.argv[1]))["modules"], sep="\n")' "$PLAN_JSON")
	mapfile -t PACKAGE_SCOPES < <(python3 -c 'import json,sys; print(*json.load(open(sys.argv[1]))["package_scopes"], sep="\n")' "$PLAN_JSON")
	((${#PLAN_MODULES[@]})) || die 'El plan no contiene módulos para desplegar.'
	BACKUP_DIR="$STATE_DIR/backups/host-$(date +%Y%m%d-%H%M%S)"
}

check_prerequisites() {
	[[ $EUID -ne 0 ]] || die "Ejecuta el instalador como usuario normal, no como root."
	command -v pacman >/dev/null || die "Esta configuración requiere Arch o CachyOS."
	command -v git >/dev/null || die "Instala primero git y base-devel con Pacman o Shelly."
	command -v stow >/dev/null || die "Instala primero GNU Stow con Pacman o Shelly."
	command -v vercmp >/dev/null || die "Falta vercmp, incluido en el paquete pacman."
	command -v shelly >/dev/null || die "Shelly no está instalado; usa el paquete oficial de CachyOS."
}

# shellcheck source=scripts/lib/install_package_ops.sh
source "$DOTFILES_DIR/scripts/lib/install_package_ops.sh"

is_safe_home_relative() {
	# Manifiestos y checkpoints solo pueden nombrar un descendiente léxico de
	# HOME.  No normalices aquí con realpath: un padre enlazado es una condición
	# distinta que se comprueba antes de mutar el destino.
	local relative=$1
	[[ -n "$relative" && "$relative" != /* && "$relative" != */ &&
		"$relative" != *//* && "$relative" != *$'\n'* && "$relative" != *$'\t'* &&
		"/$relative/" != *'/./'* && "/$relative/" != *'/../'* ]]
}

build_check_plan_intent() {
	local manifest=$1 module source relative target expected
	declare -A seen=()
	: >"$manifest"
	for module in "${PLAN_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			if ! is_safe_home_relative "$relative"; then
				warn "La composición Stow tiene una ruta de destino no válida: $relative"
				return 1
			fi
			if [[ -n "${seen[$relative]+x}" ]]; then
				warn "La composición Stow solapa el destino: $relative"
				return 1
			fi
			seen[$relative]=1
			target="$HOME/$relative"
			expected="$(expected_stow_destination "$source" "$target")" || {
				warn "No se pudo calcular la intención Stow: $relative"
				return 1
			}
			printf '%s\t%s\t%s\n' "$relative" "$expected" "$source" >>"$manifest"
		done < <(module_sources "$module")
	done
	sort -u -o "$manifest" "$manifest"
}

plan_intent_has_exact_link() {
	local manifest=$1 relative=$2 destination=$3
	is_safe_home_relative "$relative" || return 1
	awk -F $'\t' -v relative="$relative" -v destination="$destination" \
		'$1 == relative && $2 == destination && NF == 3 { found = 1 } END { exit !found }' \
		"$manifest"
}

reject_untracked_checkout_links() {
	local plan_manifest=$1 previous_manifest=$2 legacy_manifest=$3 module codex_selected=0
	for module in "${PLAN_MODULES[@]}"; do
		[[ "$module" == codex ]] && codex_selected=1
	done
	# Una shell readlink por cada enlace de HOME convierte un preflight corto en
	# minutos en perfiles con Steam, repositorios o cachés. Python recorre el
	# árbol una única vez, no sigue enlaces de directorio y conserva el destino
	# léxico exacto para no ampliar la propiedad de la composición.
	python3 "$DOTFILES_DIR/scripts/lib/checkout_link_guard.py" \
		"$HOME" "$DOTFILES_DIR" "$STATE_DIR" \
		"$plan_manifest" "$previous_manifest" "$legacy_manifest" "$codex_selected"
}

materialize_check_shadow() {
	local plan_manifest=$1 shadow_home=$2 previous_manifest=$3 legacy_manifest=$4
	local relative expected source target destination shadow_target shadow_destination
	while IFS=$'\t' read -r relative expected source; do
		[[ -n "$relative" && -n "$expected" && -n "$source" ]] || continue
		if ! is_safe_home_relative "$relative"; then
			warn "La intención Stow temporal tiene una ruta no válida: $relative"
			return 1
		fi
		target="$HOME/$relative"
		[[ -L "$target" ]] || continue
		destination="$(readlink -- "$target")"
		# The real transaction removes both previous and legacy links before
		# Stow.  Every other non-current target is moved to its reversible backup.
		if manifest_has_exact_link "$previous_manifest" "$relative" "$destination" ||
			manifest_has_exact_link "$legacy_manifest" "$relative" "$destination"; then
			continue
		fi
		[[ "$destination" == "$expected" ]] || continue
		shadow_target="$shadow_home/$relative"
		mkdir -p "$(dirname "$shadow_target")" || return 1
		# The target directory moved, so recompute Stow's lexical relative link.
		# Copying the original raw destination would create a false conflict.
		shadow_destination="$(expected_stow_destination "$source" "$shadow_target")" || return 1
		ln -s -- "$shadow_destination" "$shadow_target" || return 1
	done <"$plan_manifest"
}

check_stow_shadow() (
	set -euo pipefail
	local temporary_root=${TMPDIR:-/tmp} check_dir shadow_home plan_manifest migration_dir
	temporary_root="$(realpath -e -- "$temporary_root")"
	check_dir="$(mktemp -d "$temporary_root/dotfiles-check.XXXXXX")"
	# shellcheck disable=SC2329 # invoked by the EXIT trap below
	cleanup_check_shadow() {
		[[ "$check_dir" == "$temporary_root"/dotfiles-check.* ]] || return 1
		find "$check_dir" -depth -delete
	}
	trap cleanup_check_shadow EXIT
	shadow_home="$check_dir/home"
	migration_dir="$check_dir/migration"
	mkdir -p "$shadow_home" "$migration_dir"
	: >"$migration_dir/symlinks.tsv"

	# This reuses the exact previous-composition loader from apply, but every
	# temporary manifest lives outside HOME/XDG.  Legacy sources are checked by
	# their live raw links; apply will snapshot them before it unlinks anything.
	detect_legacy_modules
	record_legacy_links_to "$migration_dir/symlinks.tsv" || return 1
	copy_previous_applied_links_to "$migration_dir" "$migration_dir/symlinks.tsv" || return 1
	preflight_link_removal_manifest \
		"$migration_dir/previous-applied-links.tsv" \
		"$migration_dir/previous-restore-links.tsv" previous || return 1
	preflight_live_link_removal_manifest "$migration_dir/symlinks.tsv" legacy || return 1
	validate_distinct_link_removal_manifests \
		"$migration_dir/previous-applied-links.tsv" \
		"$migration_dir/symlinks.tsv" || return 1

	plan_manifest="$migration_dir/plan-intent.tsv"
	build_check_plan_intent "$plan_manifest" || return 1
	reject_untracked_checkout_links \
		"$plan_manifest" \
		"$migration_dir/previous-applied-links.tsv" \
		"$migration_dir/symlinks.tsv" || return 1
	materialize_check_shadow \
		"$plan_manifest" "$shadow_home" \
		"$migration_dir/previous-applied-links.tsv" "$migration_dir/symlinks.tsv" || return 1

	info "Simulación verbosa de Stow en HOME temporal tras retiradas y backups exactos..."
	stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --simulate --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$shadow_home" "${PLAN_MODULES[@]}"
)

preflight_migration_checkout_links() (
	set -euo pipefail
	local temporary_root=${TMPDIR:-/tmp} plan_manifest
	temporary_root="$(realpath -e -- "$temporary_root")"
	plan_manifest="$(mktemp "$temporary_root/dotfiles-plan-intent.XXXXXX")"
	# shellcheck disable=SC2329 # invoked by the EXIT trap below
	cleanup_plan_intent() {
		[[ "$plan_manifest" == "$temporary_root"/dotfiles-plan-intent.* ]] || return 1
		rm -f -- "$plan_manifest"
	}
	trap cleanup_plan_intent EXIT

	# Package and Flatpak installation can take place after the interactive
	# preflight. Re-read the live checkout links after begin_migration and before
	# generated state, backups, Stow or services can change anything.
	build_check_plan_intent "$plan_manifest" || return 1
	reject_untracked_checkout_links \
		"$plan_manifest" \
		"$MIGRATION_DIR/previous-applied-links.tsv" \
		"$MIGRATION_DIR/symlinks.tsv"
)

check_dotfiles() {
	validate_target_safety
	detect_legacy_modules
	report_legacy_targets
	report_backup_targets
	info "Validando la composición hermética con los runtimes disponibles..."
	validate_resolved_runtime 0 || return 1
	check_stow_shadow || return 1
}

plan_has_module() {
	local requested=$1 module
	for module in "${PLAN_MODULES[@]}"; do
		[[ "$module" != "$requested" ]] || return 0
	done
	return 1
}

plan_has_bundle() {
	local requested=$1 bundle
	while IFS= read -r bundle; do
		[[ "$bundle" == "$requested" ]] && return 0
	done < <(python3 -c 'import json,sys; print(*json.load(open(sys.argv[1]))["bundles"], sep="\n")' "$PLAN_JSON")
	return 1
}

is_private_env_path() {
	local relative=$1
	[[ "$relative" == .env* || "$relative" == */.env* ]]
}

legacy_dgpu_target_is_managed() {
	local target="$HOME/.config/fish/functions/dgpu.fish" link
	[[ -L "$target" ]] || return 1
	link="$(readlink "$target")"
	[[ "$link" == */fish/.config/fish/functions/dgpu.fish ]]
}

report_legacy_targets() {
	legacy_dgpu_target_is_managed || return 0
	printf 'BACKUP: %s (adaptador gpu-nvidia)\n' \
		"$HOME/.config/fish/functions/dgpu.fish"
}

is_copied_or_linked_codex_skill() {
	local relative=$1
	[[ "$relative" == .agents/skills/* ]]
}

is_stow_ignored_path() {
	local module=$1 relative=$2
	is_private_env_path "$relative" && return 0
	[[ "${relative##*/}" == .stow-local-ignore ]] && return 0
	[[ "$module" == codex ]] && is_copied_or_linked_codex_skill "$relative" && return 0
	[[ "$module" == shell && "$relative" == .local/bin/btrfs-snapshots ]] && return 0
	return 1
}

module_sources() {
	local module=$1 package_root
	package_root="$DOTFILES_DIR/$module"
	if [[ ! -f "$package_root/.stow-local-ignore" ]]; then
		find "$package_root" \( -type f -o -type l \) -print0
		return
	fi

	# `.stow-local-ignore` contiene expresiones regulares de Perl. No dupliques
	# aquí esa semántica con Bash o Python: materializa el paquete en un destino
	# privado y deja que el propio Stow decida sus fuentes exactas. Esto mantiene
	# los manifests/checkpoints alineados con Stow incluso si aparece estado local
	# ignorado dentro del checkout (por ejemplo __pycache__ o retired-skills.txt).
	(
		set -euo pipefail
		local temporary_root=${TMPDIR:-/tmp} probe_root target relative
		temporary_root="$(realpath -e -- "$temporary_root")"
		probe_root="$(mktemp -d "$temporary_root/dotfiles-stow-sources.XXXXXX")"
		# shellcheck disable=SC2329 # invoked by the EXIT trap below
		cleanup_stow_sources() {
			[[ "$probe_root" == "$temporary_root"/dotfiles-stow-sources.* ]] || return 1
			find "$probe_root" -depth -delete
		}
		trap cleanup_stow_sources EXIT

		command stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' \
			--dir "$DOTFILES_DIR" --target "$probe_root" "$module" >/dev/null
		while IFS= read -r -d '' target; do
			relative=${target#"$probe_root/"}
			printf '%s\0' "$package_root/$relative"
		done < <(find "$probe_root" -type l -print0)
	)
}

target_is_managed_dotfile() {
	local target=$1
	local resolved
	resolved="$(readlink -f "$target" 2>/dev/null || true)"
	[[ -n "$resolved" ]] || return 1
	[[ "$resolved" == "$DOTFILES_DIR"/* ||
		"$resolved" == "$HOME/.dotfiles"/* ||
		"$resolved" == "$HOME/orca/workspaces/.dotfiles"/* ]]
}

target_has_symlink_parent() {
	local parent
	parent="$(dirname "$1")"
	while [[ "$parent" == "$HOME"/* ]]; do
		[[ -L "$parent" ]] && return 0
		parent="$(dirname "$parent")"
	done
	return 1
}

validate_target_safety() {
	local module source relative target
	# No atraviesa enlaces de directorio: mover un hijo modificaría su origen real.
	for module in "${PLAN_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			is_safe_home_relative "$relative" || die 'El módulo Stow tiene una ruta no admitida.'
			target="$HOME/$relative"
			if target_has_symlink_parent "$target"; then
				die "Destino bajo un directorio enlazado; revísalo manualmente: $target"
			fi
			[[ -e "$target" || -L "$target" ]] || continue
			target_is_managed_dotfile "$target" && continue
		done < <(module_sources "$module")
	done
}

manifest_has_exact_link() {
	local manifest=$1 relative=$2 destination=$3
	is_safe_home_relative "$relative" || return 1
	[[ -f "$manifest" ]] || return 1
	awk -F $'\t' -v relative="$relative" -v destination="$destination" \
		'$1 == relative && $2 == destination && NF == 2 { found = 1 } END { exit !found }' \
		"$manifest"
}

preflight_live_link_removal_manifest() {
	local live_manifest=$1 label=$2
	local relative destination target actual failed=0
	declare -A seen=()
	[[ -f "$live_manifest" ]] || return 0
	while IFS=$'\t' read -r relative destination; do
		[[ -n "$relative" || -n "$destination" ]] || continue
		if [[ -z "$destination" || "$destination" == *$'\n'* ||
			"$destination" == *$'\t'* || -n "${seen[$relative]+x}" ]] ||
			! is_safe_home_relative "$relative"; then
			warn "El manifiesto de retirada $label no es válido: $live_manifest"
			failed=1
			continue
		fi
		seen[$relative]=1
		target="$HOME/$relative"
		if target_has_symlink_parent "$target"; then
			warn "El enlace programado para retirada tiene un padre enlazado: $target"
			failed=1
			continue
		fi
		if [[ ! -L "$target" ]]; then
			warn "Falta el enlace programado para retirada $label: $target"
			failed=1
			continue
		fi
		actual="$(readlink -- "$target")"
		if [[ "$actual" != "$destination" ]]; then
			warn "El enlace programado para retirada cambió $label: $target"
			failed=1
		fi
	done <"$live_manifest"
	return "$failed"
}

preflight_link_removal_manifest() {
	local live_manifest=$1 snapshot_manifest=$2 label=$3 failed=0
	preflight_live_link_removal_manifest "$live_manifest" "$label" || failed=1
	[[ -s "$live_manifest" ]] || return "$failed"
	if [[ ! -f "$snapshot_manifest" ]]; then
		warn "Falta el snapshot de la retirada $label: $snapshot_manifest"
		return 1
	fi
	if ! manifest_relatives_match "$live_manifest" "$snapshot_manifest"; then
		warn "El snapshot de la retirada $label no coincide con los enlaces vivos."
		failed=1
	fi
	if ! validate_restore_link_manifests "$snapshot_manifest"; then
		warn "El snapshot de la retirada $label no es privado o no es válido."
		failed=1
	fi
	return "$failed"
}

validate_distinct_link_removal_manifests() {
	local manifest relative destination failed=0
	declare -A seen=()
	for manifest in "$@"; do
		[[ -f "$manifest" ]] || continue
		while IFS=$'\t' read -r relative destination; do
			[[ -n "$relative" || -n "$destination" ]] || continue
			if [[ -z "$destination" ]] || ! is_safe_home_relative "$relative"; then
				warn "Un manifiesto de retirada tiene una ruta no válida: $manifest"
				failed=1
				continue
			fi
			if [[ -n "${seen[$relative]+x}" ]]; then
				warn "Un enlace está programado dos veces para retirada: $HOME/$relative"
				failed=1
			fi
			seen[$relative]=1
		done <"$manifest"
	done
	return "$failed"
}

preflight_scheduled_link_removals() {
	local failed=0
	validate_distinct_link_removal_manifests \
		"$MIGRATION_DIR/previous-applied-links.tsv" \
		"$MIGRATION_DIR/symlinks.tsv" || failed=1
	preflight_link_removal_manifest \
		"$MIGRATION_DIR/previous-applied-links.tsv" \
		"$MIGRATION_DIR/previous-restore-links.tsv" previous || failed=1
	preflight_link_removal_manifest \
		"$MIGRATION_DIR/symlinks.tsv" \
		"$MIGRATION_DIR/legacy-links.tsv" legacy || failed=1
	return "$failed"
}

target_is_scheduled_for_exact_removal() {
	local relative=$1 target=$2 destination
	[[ -L "$target" ]] || return 1
	destination="$(readlink -- "$target")"
	manifest_has_exact_link "$MIGRATION_DIR/previous-applied-links.tsv" "$relative" "$destination" ||
		manifest_has_exact_link "$MIGRATION_DIR/symlinks.tsv" "$relative" "$destination"
}

report_backup_targets() {
	local module source relative target
	for module in "${PLAN_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			is_safe_home_relative "$relative" || die 'El módulo Stow tiene una ruta no admitida.'
			target="$HOME/$relative"
			[[ -e "$target" || -L "$target" ]] || continue
			target_is_managed_dotfile "$target" && continue
			printf 'BACKUP: %s\n' "$target"
		done < <(module_sources "$module")
	done
}

backup_targets() {
	mkdir -p "$BACKUP_DIR"
	local module source relative target
	local backed_up=0

	validate_target_safety
	# The exact former composition is removed later by deploy_dotfiles.  Validate
	# it before moving any personal target, then leave matching links in place so
	# the guarded removal can consume them.  This matters after a rollback: its
	# live links deliberately point at private migration snapshots, not checkout.
	preflight_scheduled_link_removals || return 1
	if legacy_dgpu_target_is_managed; then
		relative=.config/fish/functions/dgpu.fish
		target="$HOME/$relative"
		if ! target_is_scheduled_for_exact_removal "$relative" "$target"; then
			mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
			record_backup_move_intent "$relative"
			mv "$target" "$BACKUP_DIR/$relative" || die "No se pudo mover al backup: $target"
			backed_up=1
		fi
	fi

	for module in "${PLAN_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			is_safe_home_relative "$relative" || die 'El módulo Stow tiene una ruta no admitida.'
			target="$HOME/$relative"

			if [[ ! -e "$target" && ! -L "$target" ]]; then
				continue
			fi
			target_is_scheduled_for_exact_removal "$relative" "$target" && continue
			target_is_managed_dotfile "$target" && continue

			mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
			record_backup_move_intent "$relative"
			mv "$target" "$BACKUP_DIR/$relative" || die "No se pudo mover al backup: $target"
			backed_up=1
		done < <(module_sources "$module")
	done

	if ((backed_up)); then
		printf '%s\n' "$BACKUP_DIR" >"$STATE_DIR/last-backup"
		ok "Copia reversible: $BACKUP_DIR"
	else
		rmdir "$BACKUP_DIR"
		info "No había destinos ajenos que respaldar."
	fi
}

record_backup_move_intent() {
	local relative=$1 manifest="$BACKUP_DIR/manifest.txt" migration_manifest="$MIGRATION_DIR/backup-moves.tsv"
	is_safe_home_relative "$relative" || die 'El journal de backup tiene una ruta no admitida.'
	if grep -Fxq -- "$relative" "$migration_manifest" 2>/dev/null; then
		return 0
	fi
	# The backup manifest is also a write-ahead journal: if mv is interrupted
	# before moving anything, restore_backup sees the original still in HOME and
	# leaves it intact; if it completed, the recorded backup is moved back.
	printf '%s\n' "$relative" >>"$migration_manifest"
	printf '%s\n' "$relative" >>"$manifest"
	persist_migration_checkpoint
	sync -f -- "$manifest" || die "No se pudo sincronizar el journal de backup: $manifest"
	sync -f -- "$BACKUP_DIR" || die "No se pudo sincronizar el directorio de backup: $BACKUP_DIR"
}

restore_backup() {
	local manifest="$MIGRATION_DIR/backup-moves.tsv"
	[[ -f "$manifest" ]] || manifest="$BACKUP_DIR/manifest.txt"
	[[ -s "$manifest" ]] || return 0
	warn "Restaurando los destinos ajenos respaldados..."

	local relative backup target failed=0
	while IFS= read -r relative; do
		if ! is_safe_home_relative "$relative"; then
			warn "El manifiesto de backup tiene una ruta no válida: $relative"
			failed=1
			continue
		fi
		backup="$BACKUP_DIR/$relative"
		target="$HOME/$relative"
		[[ -e "$backup" || -L "$backup" ]] || continue
		if [[ -e "$target" || -L "$target" ]]; then
			warn "No se restaura un backup sobre un destino ocupado: $target"
			failed=1
			continue
		fi
		if ! mkdir -p "$(dirname "$target")" || ! mv "$backup" "$target"; then
			warn "No se pudo restaurar el backup: $target"
			failed=1
		fi
	done <"$manifest"
	return "$failed"
}

detect_legacy_modules() {
	LEGACY_MODULES=()
	local module
	for module in hypr-desktop hypr-laptop gaming qmd; do
		[[ -d "$DOTFILES_DIR/$module" ]] || continue
		legacy_module_is_deployed "$module" && LEGACY_MODULES+=("$module")
	done
	return 0
}

legacy_module_is_deployed() {
	local module=$1 source relative target resolved
	while IFS= read -r -d '' source; do
		relative=${source#"$DOTFILES_DIR/$module/"}
		is_stow_ignored_path "$module" "$relative" && continue
		is_safe_home_relative "$relative" || die 'Un módulo legacy tiene una ruta no admitida.'
		target="$HOME/$relative"
		[[ -L "$target" ]] || continue
		resolved="$(readlink -f -- "$target" 2>/dev/null || true)"
		[[ "$resolved" == "$DOTFILES_DIR/$module/"* ]] && return 0
	done < <(module_sources "$module")
	return 1
}

target_points_to_legacy_module() {
	local target=$1 module resolved
	[[ -L "$target" ]] || return 1
	resolved="$(readlink -f -- "$target" 2>/dev/null || true)"
	for module in "${LEGACY_MODULES[@]}"; do
		[[ "$resolved" == "$DOTFILES_DIR/$module/"* ]] && return 0
	done
	return 1
}

generated_target_path() {
	case "$1" in
	qmd) printf '%s/qmd/index.yml\n' "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
	restic) printf '%s/restic/repository\n' "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
	noctalia) printf '%s/noctalia/zz-host-overrides.toml\n' "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
	*) return 2 ;;
	esac
}

snapshot_generated_target() {
	local key=$1 target status=absent
	target="$(generated_target_path "$key")" || die "Destino generado desconocido: $key"
	if [[ -d "$target" && ! -L "$target" ]]; then
		die "El destino generado es un directorio y requiere revisión manual: $target"
	fi
	if [[ -e "$target" || -L "$target" ]]; then
		if target_points_to_legacy_module "$target"; then
			status=legacy
		else
			status=copy
			mkdir -p "$MIGRATION_DIR/generated-backups"
			cp -a --no-dereference -- "$target" "$MIGRATION_DIR/generated-backups/$key"
		fi
	fi
	printf '%s\t%s\n' "$key" "$status" >>"$MIGRATION_DIR/generated-targets.tsv"
}

record_legacy_links_to() {
	local manifest=$1 module source relative target resolved destination
	for module in "${LEGACY_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			is_safe_home_relative "$relative" || die 'Un enlace legacy tiene una ruta no admitida.'
			target="$HOME/$relative"
			[[ -L "$target" ]] || continue
			resolved="$(readlink -f -- "$target" 2>/dev/null || true)"
			[[ "$resolved" == "$DOTFILES_DIR/$module/"* ]] || continue
			[[ "$relative" != *$'\n'* && "$relative" != *$'\t'* ]] || die 'Un enlace legacy contiene caracteres no admitidos.'
			destination="$(readlink -- "$target")"
			[[ "$destination" != *$'\n'* && "$destination" != *$'\t'* ]] || die 'Un enlace legacy contiene un destino no admitido.'
			printf '%s\t%s\n' "$relative" "$destination" >>"$manifest"
		done < <(module_sources "$module")
	done
}

record_legacy_links() {
	record_legacy_links_to "$MIGRATION_DIR/symlinks.tsv"
}

expected_stow_destination() {
	local source=$1 target=$2
	# GNU Stow writes a lexical relative destination from the target directory
	# to the package source.  Keep that exact string in the checkpoint; resolving
	# source symlinks here would make the ownership check too broad.
	python3 - "$source" "$target" <<'PY'
import os
import sys

print(os.path.relpath(sys.argv[1], os.path.dirname(sys.argv[2])))
PY
}

intent_value_for_relative() {
	local manifest=$1 relative=$2
	awk -F $'\t' -v requested="$relative" '$1 == requested { print $2; found = 1; exit } END { exit !found }' "$manifest"
}

snapshot_checkpoint_link() {
	local relative=$1 target=$2 source destination
	source="$(readlink -f -- "$target" 2>/dev/null || :)"
	[[ -n "$source" && -f "$source" ]] || die "No se puede snapshottear un enlace previo no regular: $target"
	destination="$MIGRATION_DIR/pre-stow-referents/$relative"
	mkdir -p "$(dirname "$destination")"
	cp -aL -- "$source" "$destination"
	printf '%s\t%s\n' "$relative" "$destination" >>"$MIGRATION_DIR/pre-stow-restore-links.tsv"
}

snapshot_applied_link_referents() {
	local relative expected source destination
	: >"$MIGRATION_DIR/applied-snapshot-links.tsv"
	while IFS=$'\t' read -r relative expected; do
		[[ -n "$relative" ]] || continue
		is_safe_home_relative "$relative" || die 'El manifiesto aplicado contiene una ruta no admitida.'
		source="$(intent_value_for_relative "$MIGRATION_DIR/stow-sources.tsv" "$relative")" ||
			die "Falta la fuente de la intención Stow: $relative"
		[[ -f "$source" ]] || die "No se pudo snapshot de la fuente Stow: $source"
		destination="$MIGRATION_DIR/applied-referents/$relative"
		mkdir -p "$(dirname "$destination")"
		cp -aL -- "$source" "$destination"
		printf '%s\t%s\n' "$relative" "$destination" >>"$MIGRATION_DIR/applied-snapshot-links.tsv"
	done <"$MIGRATION_DIR/applied-links.tsv"
	sort -u -o "$MIGRATION_DIR/applied-snapshot-links.tsv" "$MIGRATION_DIR/applied-snapshot-links.tsv"
}

prepare_stow_checkpoint() {
	local module source relative target expected before destination
	declare -A seen=()
	: >"$MIGRATION_DIR/stow-intent.tsv"
	: >"$MIGRATION_DIR/stow-sources.tsv"
	: >"$MIGRATION_DIR/stow-before.tsv"
	: >"$MIGRATION_DIR/pre-stow-restore-links.tsv"
	: >"$MIGRATION_DIR/applied-links.tsv"
	: >"$MIGRATION_DIR/applied-snapshot-links.tsv"
	for module in "${PLAN_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			is_safe_home_relative "$relative" || die 'La intención Stow tiene una ruta no admitida.'
			[[ -z "${seen[$relative]+x}" ]] || die "La composición Stow solapa el destino: $relative"
			seen[$relative]=1
			target="$HOME/$relative"
			expected="$(expected_stow_destination "$source" "$target")" || die "No se pudo calcular la intención Stow: $relative"
			[[ "$relative" != *$'\n'* && "$relative" != *$'\t'* &&
				"$expected" != *$'\n'* && "$expected" != *$'\t'* ]] || die 'La intención Stow contiene caracteres no admitidos.'
			printf '%s\t%s\n' "$relative" "$expected" >>"$MIGRATION_DIR/stow-intent.tsv"
			printf '%s\t%s\n' "$relative" "$source" >>"$MIGRATION_DIR/stow-sources.tsv"
		done < <(module_sources "$module")
	done
	sort -u -o "$MIGRATION_DIR/stow-intent.tsv" "$MIGRATION_DIR/stow-intent.tsv"
	sort -u -o "$MIGRATION_DIR/stow-sources.tsv" "$MIGRATION_DIR/stow-sources.tsv"
	while IFS=$'\t' read -r relative expected; do
		[[ -n "$relative" ]] || continue
		is_safe_home_relative "$relative" || die 'La intención Stow contiene una ruta no admitida.'
		target="$HOME/$relative"
		if [[ -L "$target" ]]; then
			before="$(readlink -- "$target")"
			# A link present before the durable checkpoint is only an existing
			# common link when it is lexically the exact link Stow would create.
			# Resolving it would incorrectly accept an unrelated path that happens
			# to reach the same file.  Abort before Stow so it can never become an
			# inherited active-composition entry on rollback.
			[[ "$before" == "$expected" ]] ||
				die "Destino Stow ocupado por un enlace ajeno o cambiado: $target"
			printf '%s\tlink\t%s\n' "$relative" "$before" >>"$MIGRATION_DIR/stow-before.tsv"
			snapshot_checkpoint_link "$relative" "$target"
			# applied-links is the complete live composition for later retire and
			# transitions. rollback_stow_checkpoint uses stow-before.tsv to tell a
			# pre-existing exact common link from one this transaction created.
			printf '%s\t%s\n' "$relative" "$expected" >>"$MIGRATION_DIR/applied-links.tsv"
		elif [[ -e "$target" ]]; then
			# backup_targets must have moved files first; a remaining non-link could
			# make Stow change an unknown object, so stop before the mutation.
			die "Destino Stow ocupado tras el backup: $target"
		else
			printf '%s\tabsent\t\n' "$relative" >>"$MIGRATION_DIR/stow-before.tsv"
			printf '%s\t%s\n' "$relative" "$expected" >>"$MIGRATION_DIR/applied-links.tsv"
		fi
	done <"$MIGRATION_DIR/stow-intent.tsv"
	sort -u -o "$MIGRATION_DIR/applied-links.tsv" "$MIGRATION_DIR/applied-links.tsv"
	snapshot_applied_link_referents
	: >"$MIGRATION_DIR/stow-checkpoint"
	printf '%s\n' stow-ready >"$MIGRATION_DIR/status"
	persist_migration_checkpoint
}

snapshot_legacy_link_manifest() {
	local manifest="$MIGRATION_DIR/legacy-links.tsv"
	local module source relative destination
	: >"$manifest"
	for module in "${LEGACY_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			is_safe_home_relative "$relative" || die 'El snapshot legacy tiene una ruta no admitida.'
			# Only restore the exact links that were active before the transaction.
			grep -Fq -- "$relative"$'\t' "$MIGRATION_DIR/symlinks.tsv" || continue
			destination="$MIGRATION_DIR/modules/$module/$relative"
			printf '%s\t%s\n' "$relative" "$destination" >>"$manifest"
		done < <(module_sources "$module")
	done
	sort -u -o "$manifest" "$manifest"
}

copy_manifest_without_legacy() {
	local source=$1 legacy_manifest=$2 destination=$3
	: >"$destination"
	[[ -f "$source" ]] || return 0
	if [[ ! -s "$legacy_manifest" ]]; then
		cp -- "$source" "$destination"
		return 0
	fi
	# A rolled-back migration can describe both the profileless composition and
	# legacy links that never left HOME.  The latter belong to this transaction's
	# legacy manifest, otherwise deploy_dotfiles would try to remove them twice.
	awk -F $'\t' 'NR == FNR { legacy[$1] = 1; next } !($1 in legacy)' \
		"$legacy_manifest" "$source" >"$destination"
}

manifest_relatives_match() {
	local live=$1 snapshots=$2
	cmp -s \
		<(cut -f1 "$live" | sort -u) \
		<(cut -f1 "$snapshots" | sort -u)
}

copy_previous_applied_links_to() {
	local destination_dir=$1 legacy_manifest=$2
	local previous="${STATE_DIR}/last-migration" previous_dir live_manifest snapshot_manifest snapshot_fallback
	: >"$destination_dir/previous-applied-links.tsv"
	: >"$destination_dir/previous-restore-links.tsv"
	[[ -f "$previous" ]] || return 0
	previous_dir="$(<"$previous")"
	[[ "$previous_dir" == "$STATE_DIR/migrations/"* && -f "$previous_dir/status" ]] ||
		die "La referencia a la última migración no es segura o está incompleta: $previous_dir"
	case "$(<"$previous_dir/status")" in
	applied)
		live_manifest="$previous_dir/applied-links.tsv"
		snapshot_manifest="$previous_dir/applied-snapshot-links.tsv"
		;;
	rolled-back)
		live_manifest="$previous_dir/restored-active-links.tsv"
		snapshot_manifest="$previous_dir/restored-snapshot-links.tsv"
		if [[ ! -f "$snapshot_manifest" ]]; then
			# Migrations written before restored-snapshot-links.tsv can still be
			# retried only if both of their private snapshot manifests survive.
			snapshot_fallback="$destination_dir/previous-snapshot-fallback.tsv"
			: >"$snapshot_fallback"
			[[ -f "$previous_dir/previous-restore-links.tsv" ]] && cat "$previous_dir/previous-restore-links.tsv" >>"$snapshot_fallback"
			[[ -f "$previous_dir/legacy-links.tsv" ]] && cat "$previous_dir/legacy-links.tsv" >>"$snapshot_fallback"
			snapshot_manifest="$snapshot_fallback"
		fi
		;;
	retired) return 0 ;;
	*) die "La última migración no terminó de forma segura ($(<"$previous_dir/status")); ejecuta rollback antes de volver a desplegar." ;;
	esac
	[[ -f "$live_manifest" ]] || return 0
	copy_manifest_without_legacy "$live_manifest" "$legacy_manifest" "$destination_dir/previous-applied-links.tsv"
	if [[ -s "$destination_dir/previous-applied-links.tsv" && ! -f "$snapshot_manifest" ]]; then
		die "La composición aplicada anterior no tiene snapshot de enlaces: $previous_dir"
	fi
	[[ -f "$snapshot_manifest" ]] || return 0
	copy_manifest_without_legacy "$snapshot_manifest" "$legacy_manifest" "$destination_dir/previous-restore-links.tsv"
	if [[ -s "$destination_dir/previous-applied-links.tsv" && ! -s "$destination_dir/previous-restore-links.tsv" ]]; then
		die "El snapshot de enlaces anterior no cubre la composición activa: $previous_dir"
	fi
	if ! manifest_relatives_match "$destination_dir/previous-applied-links.tsv" "$destination_dir/previous-restore-links.tsv"; then
		die "El snapshot de enlaces anterior no coincide con la composición activa: $previous_dir"
	fi
	validate_restore_link_manifests "$destination_dir/previous-restore-links.tsv" ||
		die "El snapshot de enlaces anterior no es restaurable: $previous_dir"
}

copy_previous_applied_links() {
	copy_previous_applied_links_to "$MIGRATION_DIR" "$MIGRATION_DIR/symlinks.tsv"
}

copy_previous_generated_targets() {
	local previous="${STATE_DIR}/last-migration" previous_dir
	: >"$MIGRATION_DIR/previous-generated-installed.tsv"
	[[ -f "$previous" ]] || return 0
	previous_dir="$(<"$previous")"
	[[ "$previous_dir" == "$STATE_DIR/migrations/"* && -f "$previous_dir/status" ]] || return 0
	case "$(<"$previous_dir/status")" in
	applied)
		[[ -f "$previous_dir/generated-installed.tsv" ]] || return 0
		cp -- "$previous_dir/generated-installed.tsv" "$MIGRATION_DIR/previous-generated-installed.tsv"
		;;
	rolled-back)
		[[ -f "$previous_dir/restored-active-generated.tsv" ]] || return 0
		cp -- "$previous_dir/restored-active-generated.tsv" "$MIGRATION_DIR/previous-generated-installed.tsv"
		;;
	esac
}

write_restored_active_links() {
	local relative destination target
	declare -A seen=() allowed=()
	# Build the allow-list from both original and private snapshot targets.  An
	# intent may have been durable while a preflight rejected its removal; the
	# original link remains live in that case and must not be rewritten as a
	# foreign link in the next migration.
	while IFS=$'\t' read -r relative destination; do
		[[ -n "$relative" && -n "$destination" ]] || continue
		if ! is_safe_home_relative "$relative"; then
			warn "La composición restaurada contiene una ruta no válida: $relative"
			return 1
		fi
		allowed[$relative]+="$destination"$'\n'
	done < <(cat \
		"$MIGRATION_DIR/previous-applied-links.tsv" \
		"$MIGRATION_DIR/previous-restore-links.tsv" \
		"$MIGRATION_DIR/symlinks.tsv" \
		"$MIGRATION_DIR/legacy-links.tsv" \
		"$MIGRATION_DIR/checkpoint-restored-active-links.tsv" \
		"$MIGRATION_DIR/checkpoint-restored-snapshot-links.tsv" 2>/dev/null)
	: >"$MIGRATION_DIR/restored-active-links.tsv"
	for relative in "${!allowed[@]}"; do
		[[ -n "$relative" && -z "${seen[$relative]+x}" ]] || continue
		is_safe_home_relative "$relative" || return 1
		seen[$relative]=1
		target="$HOME/$relative"
		[[ -L "$target" ]] || continue
		destination="$(readlink -- "$target")"
		grep -Fqx -- "$destination" <<<"${allowed[$relative]}" || continue
		printf '%s\t%s\n' "$relative" "$destination" >>"$MIGRATION_DIR/restored-active-links.tsv"
	done
	sort -u -o "$MIGRATION_DIR/restored-active-links.tsv" "$MIGRATION_DIR/restored-active-links.tsv"
}

write_restored_snapshot_links() {
	# Unlike restored-active-links.tsv, this never records a checkout target.
	# It is the immutable source for the next transaction's rollback snapshot.
	local relative snapshot
	declare -A active=()
	while IFS=$'\t' read -r relative _; do
		[[ -n "$relative" ]] && active[$relative]=1
	done <"$MIGRATION_DIR/restored-active-links.tsv"
	: >"$MIGRATION_DIR/restored-snapshot-links.tsv"
	while IFS=$'\t' read -r relative snapshot; do
		[[ -n "$relative" && -n "${active[$relative]+x}" ]] || continue
		valid_private_checkpoint_snapshot "$snapshot" || {
			warn "Falta el snapshot privado del enlace restaurado: $snapshot"
			return 1
		}
		printf '%s\t%s\n' "$relative" "$snapshot" >>"$MIGRATION_DIR/restored-snapshot-links.tsv"
	done < <(cat "$MIGRATION_DIR/previous-restore-links.tsv" "$MIGRATION_DIR/legacy-links.tsv" \
		"$MIGRATION_DIR/checkpoint-restored-snapshot-links.tsv" 2>/dev/null)
	if cut -f1 "$MIGRATION_DIR/restored-snapshot-links.tsv" | sort | uniq -d | grep -q .; then
		warn 'Los snapshots restaurados contienen destinos solapados.'
		return 1
	fi
	if ! manifest_relatives_match "$MIGRATION_DIR/restored-active-links.tsv" "$MIGRATION_DIR/restored-snapshot-links.tsv"; then
		warn 'Los enlaces restaurados no tienen snapshots privados equivalentes.'
		return 1
	fi
	sort -u -o "$MIGRATION_DIR/restored-snapshot-links.tsv" "$MIGRATION_DIR/restored-snapshot-links.tsv"
}

write_restored_active_generated() {
	local key expected target actual
	: >"$MIGRATION_DIR/restored-active-generated.tsv"
	while IFS=$'\t' read -r key expected; do
		[[ -n "$key" ]] || continue
		target="$(generated_target_path "$key")" || continue
		[[ -f "$target" && ! -L "$target" ]] || continue
		actual="$(sha256sum -- "$target" | cut -d' ' -f1)"
		[[ "$actual" == "$expected" ]] || continue
		printf '%s\t%s\n' "$key" "$expected" >>"$MIGRATION_DIR/restored-active-generated.tsv"
	done <"$MIGRATION_DIR/previous-generated-installed.tsv"
}

remove_link_manifest() {
	local manifest=$1 line relative destination target failed=0
	local -a destinations=() targets=()
	[[ -f "$manifest" ]] || return 0
	# Validate every entry before unlinking anything. A later manual edit must
	# leave the whole composition intact rather than produce a partial removal.
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -n "$line" ]] || continue
		relative=${line%%$'\t'*}
		destination=${line#*$'\t'}
		if [[ "$line" == "$relative" || -z "$destination" || "$destination" == *$'\t'* ]] ||
			! is_safe_home_relative "$relative"; then
			warn "El manifiesto de enlaces gestionados no es válido: $manifest"
			failed=1
			continue
		fi
		target="$HOME/$relative"
		if [[ ! -L "$target" || "$(readlink -- "$target")" != "$destination" ]]; then
			warn "El enlace gestionado cambió y no se retira: $target"
			failed=1
			continue
		fi
		destinations+=("$destination")
		targets+=("$target")
	done <"$manifest"
	((failed == 0)) || return 1
	local index
	for ((index = 0; index < ${#targets[@]}; index++)); do
		target=${targets[index]}
		if [[ ! -L "$target" || "$(readlink -- "$target")" != "${destinations[index]}" ]]; then
			warn "El enlace gestionado cambió durante la retirada: $target"
			return 1
		fi
		if ! rm -- "$target"; then
			warn "No se pudo retirar el enlace gestionado: $target"
			return 1
		fi
	done
}

restore_link_manifest() {
	local manifest=$1 relative destination resolved target failed=0
	[[ -f "$manifest" ]] || return 0
	while IFS=$'\t' read -r relative destination; do
		[[ -n "$relative" ]] || continue
		if ! is_safe_home_relative "$relative"; then
			warn "No se restaura una ruta fuera de HOME: $relative"
			failed=1
			continue
		fi
		resolved="$(readlink -f -- "$destination" 2>/dev/null || :)"
		if [[ "$resolved" != "$STATE_DIR/migrations/"* || ! -f "$resolved" ]]; then
			warn "No se restaura un enlace cuyo snapshot no existe: $destination"
			failed=1
			continue
		fi
		target="$HOME/$relative"
		if [[ -e "$target" || -L "$target" ]]; then
			warn "No se restaura un enlace sobre un destino ocupado: $target"
			failed=1
		fi
	done <"$manifest"
	((failed == 0)) || return 1
	while IFS=$'\t' read -r relative destination; do
		[[ -n "$relative" ]] || continue
		is_safe_home_relative "$relative" || return 1
		target="$HOME/$relative"
		mkdir -p "$(dirname "$target")"
		ln -s -- "$destination" "$target"
	done <"$manifest"
}

restore_removed_link_manifest() {
	local snapshots=$1 live=$2 completion=$3 relative snapshot expected target current failed=0
	local -a restore_relatives=() restore_snapshots=()
	declare -A live_destinations=() seen=()
	[[ -f "$snapshots" && -f "$live" ]] || return 0
	while IFS=$'\t' read -r relative expected; do
		if ! [[ -n "$relative" && -n "$expected" && -z "${live_destinations[$relative]+x}" ]] ||
			! is_safe_home_relative "$relative"; then
			warn "El manifiesto vivo de retirada no es válido: $live"
			return 1
		fi
		live_destinations[$relative]=$expected
	done <"$live"
	while IFS=$'\t' read -r relative snapshot; do
		if ! [[ -n "$relative" && -n "$snapshot" && -n "${live_destinations[$relative]+x}" && -z "${seen[$relative]+x}" ]] ||
			! is_safe_home_relative "$relative"; then
			warn "El manifiesto de snapshot de retirada no es válido: $snapshots"
			return 1
		fi
		seen[$relative]=1
		valid_private_checkpoint_snapshot "$snapshot" || {
			warn "Falta el snapshot de retirada: $snapshot"
			return 1
		}
		target="$HOME/$relative"
		expected=${live_destinations[$relative]}
		if [[ ! -e "$target" && ! -L "$target" ]]; then
			restore_relatives+=("$relative")
			restore_snapshots+=("$snapshot")
		elif [[ -L "$target" ]]; then
			current="$(readlink -- "$target")"
			if [[ "$current" != "$expected" && "$current" != "$snapshot" ]]; then
				if [[ -f "$completion" ]]; then
					warn "No se sobrescribe un enlace ajeno durante el rollback: $target"
					failed=1
				else
					# The all-or-nothing preflight may have rejected the removal
					# before it touched HOME.  Without its completion marker this
					# can be an independent edit, so retain it rather than calling
					# it transaction-owned.
					warn "El enlace cambió antes de completar su retirada; se conserva: $target"
				fi
			fi
		else
			if [[ -f "$completion" ]]; then
				warn "No se sobrescribe un archivo ajeno durante el rollback: $target"
				failed=1
			else
				warn "El archivo cambió antes de completar su retirada; se conserva: $target"
			fi
		fi
	done <"$snapshots"
	((failed == 0)) || return 1
	for ((i = 0; i < ${#restore_relatives[@]}; i++)); do
		target="$HOME/${restore_relatives[i]}"
		if ! mkdir -p "$(dirname "$target")" || ! ln -s -- "${restore_snapshots[i]}" "$target"; then
			warn "No se pudo restaurar un enlace retirado: $target"
			return 1
		fi
	done
}

record_link_removal_intent() {
	local marker=$1 manifest=$2
	[[ -s "$manifest" ]] || return 0
	: >"$marker"
	persist_migration_checkpoint
}

record_link_removal_complete() {
	local marker=$1 manifest=$2
	[[ -s "$manifest" ]] || return 0
	: >"$marker"
	persist_migration_checkpoint
}

validate_restore_link_manifests() {
	local manifest relative destination resolved failed=0
	declare -A seen=()
	for manifest in "$@"; do
		[[ -f "$manifest" ]] || continue
		while IFS=$'\t' read -r relative destination; do
			[[ -n "$relative" ]] || continue
			if ! is_safe_home_relative "$relative"; then
				warn "El snapshot de rollback tiene una ruta no válida: $relative"
				failed=1
				continue
			fi
			if [[ -n "${seen[$relative]+x}" ]]; then
				warn "Los snapshots de rollback se solapan en: $relative"
				failed=1
			fi
			seen[$relative]=1
			resolved="$(readlink -f -- "$destination" 2>/dev/null || :)"
			if [[ "$resolved" != "$STATE_DIR/migrations/"* || ! -f "$resolved" ]]; then
				warn "Falta o no es privado el snapshot de rollback: $destination"
				failed=1
			fi
		done <"$manifest"
	done
	return "$failed"
}

checkpoint_snapshot_for_relative() {
	intent_value_for_relative "$MIGRATION_DIR/pre-stow-restore-links.tsv" "$1"
}

valid_private_checkpoint_snapshot() {
	local snapshot=$1 resolved
	resolved="$(readlink -f -- "$snapshot" 2>/dev/null || :)"
	[[ "$resolved" == "$STATE_DIR/migrations/"* && -f "$resolved" ]]
}

rollback_stow_checkpoint() {
	local relative expected kind before target current snapshot failed=0
	local -a remove_relatives=() restore_relatives=() restore_snapshots=()
	declare -A intents=() before_kind=() before_destination=()
	# New-format migrations publish this durable marker in begin_migration,
	# before prepare_stow_checkpoint starts building its manifests.  If a later
	# preparation error leaves applied-links.tsv partial but no checkpoint, the
	# real Stow command has not run yet.  Do not mistake that scratch manifest
	# for an old transaction and delete a pre-existing common link.
	if [[ ! -f "$MIGRATION_DIR/stow-checkpoint" ]]; then
		if [[ -e "$MIGRATION_DIR/stow-checkpoint-format" || -L "$MIGRATION_DIR/stow-checkpoint-format" ]]; then
			if [[ -L "$MIGRATION_DIR/stow-checkpoint-format" || ! -f "$MIGRATION_DIR/stow-checkpoint-format" || $(<"$MIGRATION_DIR/stow-checkpoint-format") != v1 ]]; then
				warn 'El marcador de formato del checkpoint Stow no es válido.'
				return 1
			fi
			return 0
		fi
		# Old completed migrations have no checkpoint marker. Their existing
		# manifest is still guarded by exact readlink matching for compatibility.
		remove_link_manifest "$MIGRATION_DIR/applied-links.tsv"
		return
	fi
	while IFS=$'\t' read -r relative expected; do
		if ! [[ -n "$relative" && -n "$expected" && -z "${intents[$relative]+x}" ]] ||
			! is_safe_home_relative "$relative"; then
			warn 'La intención Stow del checkpoint no es válida.'
			return 1
		fi
		intents[$relative]=$expected
	done <"$MIGRATION_DIR/stow-intent.tsv"
	while IFS=$'\t' read -r relative kind before; do
		if ! [[ -n "$relative" && -n "$kind" && -n "${intents[$relative]+x}" && -z "${before_kind[$relative]+x}" ]] ||
			! is_safe_home_relative "$relative"; then
			warn 'El estado previo Stow del checkpoint no es válido.'
			return 1
		fi
		[[ "$kind" == absent || "$kind" == link ]] || {
			warn 'El tipo del estado previo Stow no es válido.'
			return 1
		}
		before_kind[$relative]=$kind
		before_destination[$relative]=$before
	done <"$MIGRATION_DIR/stow-before.tsv"
	for relative in "${!intents[@]}"; do
		if ! is_safe_home_relative "$relative" || ! [[ -n "${before_kind[$relative]+x}" ]]; then
			warn "Falta el estado previo Stow: $relative"
			return 1
		fi
		expected=${intents[$relative]}
		kind=${before_kind[$relative]}
		before=${before_destination[$relative]}
		if [[ "$kind" == link && "$before" != "$expected" ]]; then
			warn "El checkpoint Stow contiene un enlace previo ajeno: $HOME/$relative"
			failed=1
			continue
		fi
		target="$HOME/$relative"
		if [[ -L "$target" ]]; then
			current="$(readlink -- "$target")"
		else
			current=''
		fi
		case "$kind" in
		absent)
			if [[ "$current" == "$expected" ]]; then
				remove_relatives+=("$relative")
			elif [[ -e "$target" || -L "$target" ]]; then
				warn "No se retira un enlace/archivo ajeno de carrera: $target"
				failed=1
			fi
			;;
		link)
			if [[ "$current" == "$before" ]]; then
				:
			elif [[ "$current" == "$expected" && "$before" == "$expected" ]]; then
				# It was already the desired common/shared link before this run.
				:
			elif [[ "$current" == "$expected" ]] || { [[ -z "$current" && ! -e "$target" ]]; }; then
				snapshot="$(checkpoint_snapshot_for_relative "$relative" || :)"
				if ! valid_private_checkpoint_snapshot "$snapshot"; then
					warn "Falta el snapshot previo Stow: $relative"
					failed=1
					continue
				fi
				[[ "$current" == "$expected" ]] && remove_relatives+=("$relative")
				restore_relatives+=("$relative")
				restore_snapshots+=("$snapshot")
			else
				warn "No se sobrescribe un enlace/archivo ajeno de carrera: $target"
				failed=1
			fi
			;;
		esac
	done
	((failed == 0)) || return 1
	for relative in "${remove_relatives[@]}"; do
		is_safe_home_relative "$relative" || return 1
		if ! rm -- "$HOME/$relative"; then
			warn "No se pudo retirar el enlace Stow del checkpoint: $HOME/$relative"
			return 1
		fi
	done
	for ((i = 0; i < ${#restore_relatives[@]}; i++)); do
		relative=${restore_relatives[i]}
		target="$HOME/$relative"
		if [[ -e "$target" || -L "$target" ]]; then
			warn "No se restaura el enlace previo Stow sobre un destino ocupado: $target"
			return 1
		fi
		if ! mkdir -p "$(dirname "$target")" || ! ln -s -- "${restore_snapshots[i]}" "$target"; then
			warn "No se pudo restaurar el enlace previo Stow: $target"
			return 1
		fi
	done
}

verify_stow_checkpoint_applied() {
	local relative expected target failed=0
	while IFS=$'\t' read -r relative expected; do
		[[ -n "$relative" ]] || continue
		if ! is_safe_home_relative "$relative"; then
			warn "El checkpoint Stow contiene una ruta no válida: $relative"
			failed=1
			continue
		fi
		target="$HOME/$relative"
		if [[ ! -L "$target" || "$(readlink -- "$target")" != "$expected" ]]; then
			warn "Stow no creó el enlace esperado del checkpoint: $target"
			failed=1
		fi
	done <"$MIGRATION_DIR/applied-links.tsv"
	return "$failed"
}

write_checkpoint_restored_links() {
	local relative kind before expected target current snapshot failed=0
	: >"$MIGRATION_DIR/checkpoint-restored-active-links.tsv"
	: >"$MIGRATION_DIR/checkpoint-restored-snapshot-links.tsv"
	[[ -f "$MIGRATION_DIR/stow-checkpoint" ]] || return 0
	while IFS=$'\t' read -r relative kind before; do
		[[ "$kind" == link ]] || continue
		if ! is_safe_home_relative "$relative"; then
			warn "El checkpoint Stow contiene una ruta no válida: $relative"
			failed=1
			continue
		fi
		expected="$(intent_value_for_relative "$MIGRATION_DIR/stow-intent.tsv" "$relative" || :)"
		if [[ -z "$expected" || "$before" != "$expected" ]]; then
			warn "El checkpoint Stow no puede promocionar un enlace previo ajeno: $HOME/$relative"
			failed=1
			continue
		fi
		target="$HOME/$relative"
		if [[ ! -L "$target" ]]; then
			# The source was a link before Stow, so an absent target here means a
			# rollback bug or an external change.  Do not publish a false active
			# composition for the next transaction.
			warn "El enlace previo Stow no sobrevivió al rollback: $target"
			failed=1
			continue
		fi
		current="$(readlink -- "$target")"
		snapshot="$(checkpoint_snapshot_for_relative "$relative" || :)"
		if ! valid_private_checkpoint_snapshot "$snapshot"; then
			warn "Falta el snapshot del enlace previo Stow: $relative"
			failed=1
			continue
		fi
		if [[ "$current" != "$before" && "$current" != "$snapshot" ]]; then
			warn "El enlace previo Stow cambió durante el rollback: $target"
			failed=1
			continue
		fi
		printf '%s\t%s\n' "$relative" "$current" >>"$MIGRATION_DIR/checkpoint-restored-active-links.tsv"
		printf '%s\t%s\n' "$relative" "$snapshot" >>"$MIGRATION_DIR/checkpoint-restored-snapshot-links.tsv"
	done <"$MIGRATION_DIR/stow-before.tsv"
	((failed == 0)) || return 1
	sort -u -o "$MIGRATION_DIR/checkpoint-restored-active-links.tsv" "$MIGRATION_DIR/checkpoint-restored-active-links.tsv"
	sort -u -o "$MIGRATION_DIR/checkpoint-restored-snapshot-links.tsv" "$MIGRATION_DIR/checkpoint-restored-snapshot-links.tsv"
}

write_migration_checksums() {
	(
		cd "$MIGRATION_DIR"
		find . -type f ! -name SHA256SUMS ! -name status -print0 |
			sort -z | xargs -0 -r sha256sum
	) >"$MIGRATION_DIR/SHA256SUMS"
}

persist_migration_checkpoint() {
	local path
	write_migration_checksums
	command -v sync >/dev/null 2>&1 || die 'sync no está disponible; no se puede confirmar un checkpoint de migración durable.'
	# A journal is written before every HOME mutation.  Flush the records, their
	# checksum and the directory entry so power loss cannot expose an unrecorded
	# Stow/generated change.  Abort rather than claim a recoverable transaction
	# on a platform without file and directory sync support.
	while IFS= read -r -d '' path; do
		sync -f -- "$path" || die "No se pudo sincronizar el checkpoint: $path"
	done < <(find "$MIGRATION_DIR" -type f -print0)
	sync -f -- "$MIGRATION_DIR" || die "No se pudo sincronizar el directorio del checkpoint: $MIGRATION_DIR"
	sync -f -- "$(dirname "$MIGRATION_DIR")" || die 'No se pudo sincronizar el índice de migraciones.'
}

derived_fingerprint() {
	local relative target entry entry_relative digest
	for relative in generated staged plans/resolved.json; do
		target="$STATE_DIR/$relative"
		if [[ -L "$target" ]]; then
			printf 'L\t%s\t%s\n' "$relative" "$(readlink -- "$target")"
		elif [[ -f "$target" ]]; then
			digest="$(sha256sum -- "$target" | cut -d' ' -f1)"
			printf 'F\t%s\t%s\n' "$relative" "$digest"
		elif [[ -d "$target" ]]; then
			printf 'D\t%s\n' "$relative"
			while IFS= read -r -d '' entry; do
				entry_relative=${entry#"$STATE_DIR/"}
				if [[ -L "$entry" ]]; then
					printf 'L\t%s\t%s\n' "$entry_relative" "$(readlink -- "$entry")"
				elif [[ -f "$entry" ]]; then
					digest="$(sha256sum -- "$entry" | cut -d' ' -f1)"
					printf 'F\t%s\t%s\n' "$entry_relative" "$digest"
				elif [[ -d "$entry" ]]; then
					printf 'D\t%s\n' "$entry_relative"
				fi
			done < <(find "$target" -mindepth 1 -print0 | sort -z)
		else
			printf 'A\t%s\n' "$relative"
		fi
	done
}

snapshot_derived_state() {
	local relative source destination
	mkdir -p "$MIGRATION_DIR/derived-before/plans"
	derived_fingerprint >"$MIGRATION_DIR/derived-before.tsv"
	for relative in generated staged plans/resolved.json; do
		source="$STATE_DIR/$relative"
		[[ -e "$source" || -L "$source" ]] || continue
		destination="$MIGRATION_DIR/derived-before/$relative"
		mkdir -p "$(dirname "$destination")"
		cp -a --no-dereference -- "$source" "$destination"
	done
	: >"$MIGRATION_DIR/derived-installed.tsv"
}

record_derived_state() {
	derived_fingerprint >"$MIGRATION_DIR/derived-installed.tsv"
	persist_migration_checkpoint
}

record_derived_mutation_intent() {
	: >"$MIGRATION_DIR/derived-mutation-intent"
	persist_migration_checkpoint
}

restore_derived_state() {
	local current relative source destination failed=0
	[[ -f "$MIGRATION_DIR/derived-mutation-intent" || -s "$MIGRATION_DIR/derived-installed.tsv" ]] || return 0
	current="$(mktemp "${TMPDIR:-/tmp}/dotfiles-derived.XXXXXX")"
	derived_fingerprint >"$current"
	if [[ ! -s "$MIGRATION_DIR/derived-installed.tsv" ]]; then
		if cmp -s "$MIGRATION_DIR/derived-before.tsv" "$current"; then
			rm -f -- "$current"
			return 0
		fi
		warn 'El resolutor pudo interrumpirse antes de registrar su estado derivado; no se sobrescribe.'
		rm -f -- "$current"
		return 1
	fi
	if ! cmp -s "$MIGRATION_DIR/derived-installed.tsv" "$current"; then
		warn 'El estado derivado cambió después del despliegue; no se sobrescribe.'
		rm -f -- "$current"
		return 1
	fi
	rm -f -- "$current"
	for relative in generated staged plans/resolved.json; do
		destination="$STATE_DIR/$relative"
		if [[ -d "$destination" && ! -L "$destination" ]]; then
			rm -rf -- "$destination"
		else
			rm -f -- "$destination"
		fi
	done
	for relative in generated staged plans/resolved.json; do
		source="$MIGRATION_DIR/derived-before/$relative"
		destination="$STATE_DIR/$relative"
		[[ -e "$source" || -L "$source" ]] || continue
		mkdir -p "$(dirname "$destination")"
		cp -a --no-dereference -- "$source" "$destination" || failed=1
	done
	return "$failed"
}

begin_migration() {
	detect_legacy_modules
	mkdir -p "$STATE_DIR/migrations"
	MIGRATION_DIR="$(mktemp -d "$STATE_DIR/migrations/deployment-$(date +%Y%m%d-%H%M%S).XXXXXX")"
	chmod 700 "$MIGRATION_DIR"
	mkdir -p "$MIGRATION_DIR/modules"
	git -C "$DOTFILES_DIR" rev-parse HEAD >"$MIGRATION_DIR/oid" 2>/dev/null || printf '%s\n' unversioned >"$MIGRATION_DIR/oid"
	cp -- "$PLAN_JSON" "$MIGRATION_DIR/plan.json"
	printf '%s\n' "$BACKUP_DIR" >"$MIGRATION_DIR/backup-dir"
	: >"$MIGRATION_DIR/legacy-modules"
	: >"$MIGRATION_DIR/symlinks.tsv"
	: >"$MIGRATION_DIR/generated-targets.tsv"
	: >"$MIGRATION_DIR/generated-installed.tsv"
	: >"$MIGRATION_DIR/generated-removed.tsv"
	: >"$MIGRATION_DIR/backup-moves.tsv"
	: >"$MIGRATION_DIR/applied-links.tsv"
	: >"$MIGRATION_DIR/applied-snapshot-links.tsv"
	: >"$MIGRATION_DIR/stow-intent.tsv"
	: >"$MIGRATION_DIR/stow-sources.tsv"
	: >"$MIGRATION_DIR/stow-before.tsv"
	: >"$MIGRATION_DIR/pre-stow-restore-links.tsv"
	# This versioned marker is durable with the initial transaction snapshot.
	# It distinguishes an interrupted checkpoint *preparation* (where Stow did
	# not run) from a legacy transaction that genuinely predates checkpoints.
	printf '%s\n' v1 >"$MIGRATION_DIR/stow-checkpoint-format"
	rm -f -- "$MIGRATION_DIR/previous-links-removed"
	rm -f -- "$MIGRATION_DIR/legacy-links-removed"
	rm -f -- "$MIGRATION_DIR/previous-links-removal-intent"
	rm -f -- "$MIGRATION_DIR/legacy-links-removal-intent"
	rm -f -- "$MIGRATION_DIR/stow-checkpoint"
	((${#LEGACY_MODULES[@]})) && printf '%s\n' "${LEGACY_MODULES[@]}" >"$MIGRATION_DIR/legacy-modules"
	record_legacy_links
	# Follow source links while taking the private legacy snapshot.  Restoring a
	# preserved source symlink would otherwise still depend on the checkout.
	for module in "${LEGACY_MODULES[@]}"; do cp -aL -- "$DOTFILES_DIR/$module" "$MIGRATION_DIR/modules/$module"; done
	snapshot_legacy_link_manifest
	copy_previous_applied_links
	copy_previous_generated_targets
	snapshot_generated_target qmd
	snapshot_generated_target restic
	snapshot_generated_target noctalia
	snapshot_derived_state
	printf '%s\n' prepared >"$MIGRATION_DIR/status"
	persist_migration_checkpoint
	printf '%s\n' "$MIGRATION_DIR" >"$STATE_DIR/last-migration"
	sync -f -- "$STATE_DIR/last-migration" || die 'No se pudo sincronizar la referencia de la migración.'
	sync -f -- "$STATE_DIR" || die 'No se pudo sincronizar el estado de migración.'
	sync -f -- "$(dirname "$STATE_DIR")" || die 'No se pudo sincronizar el índice del estado de migración.'
	info "Transacción reversible preparada: $MIGRATION_DIR"
}

generated_snapshot_matches_target() {
	local key=$1 target=$2 snapshot actual expected
	snapshot="$MIGRATION_DIR/generated-backups/$key"
	if [[ -L "$snapshot" ]]; then
		[[ -L "$target" && "$(readlink -- "$target")" == "$(readlink -- "$snapshot")" ]]
		return
	fi
	[[ -f "$snapshot" && -f "$target" && ! -L "$target" ]] || return 1
	expected="$(sha256sum -- "$snapshot" | cut -d' ' -f1)"
	actual="$(sha256sum -- "$target" | cut -d' ' -f1)"
	[[ "$actual" == "$expected" ]]
}

record_generated_intent() {
	local manifest=$1 key=$2 checksum=$3
	[[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || die "Checksum generado inválido para $key"
	if grep -Fqx -- "$key"$'\t'"$checksum" "$manifest"; then
		return 0
	fi
	if grep -Fq -- "$key"$'\t' "$manifest"; then
		die "El journal generado contiene dos intenciones para $key"
	fi
	# The journal is durable before the target changes.  A SIGKILL between this
	# append and mv/rm is harmless: rollback recognises the original bytes and
	# leaves them in place.  A SIGKILL after the mutation has the exact digest
	# needed to remove or restore it.
	printf '%s\t%s\n' "$key" "$checksum" >>"$manifest"
	persist_migration_checkpoint
}

restore_generated_targets() {
	local key expected target status snapshot actual failed=0
	local -a remove_targets=() restore_keys=()
	declare -A statuses=() installed=() removed=() remove_after=()
	while IFS=$'\t' read -r key status; do
		[[ -n "$key" ]] || continue
		if [[ "$key" == rgb && "$status" =~ ^(absent|legacy|copy)$ ]]; then
			continue
		fi
		[[ "$key" =~ ^(qmd|restic|noctalia)$ && "$status" =~ ^(absent|legacy|copy)$ && -z "${statuses[$key]+x}" ]] || {
			warn "Estado generado no reconocido: $key/$status"
			return 1
		}
		statuses[$key]=$status
	done <"$MIGRATION_DIR/generated-targets.tsv"
	while IFS=$'\t' read -r key expected; do
		[[ -n "$key" ]] || continue
		if [[ "$key" == rgb && "$expected" =~ ^[0-9a-f]{64}$ ]]; then
			continue
		fi
		[[ "$key" =~ ^(qmd|restic|noctalia)$ && "$expected" =~ ^[0-9a-f]{64}$ && -n "${statuses[$key]+x}" && -z "${installed[$key]+x}" ]] || {
			warn "Journal de instalación generado inválido: $key"
			return 1
		}
		installed[$key]=$expected
	done <"$MIGRATION_DIR/generated-installed.tsv"
	while IFS=$'\t' read -r key expected; do
		[[ -n "$key" ]] || continue
		if [[ "$key" == rgb && "$expected" =~ ^[0-9a-f]{64}$ ]]; then
			continue
		fi
		[[ "$key" =~ ^(qmd|restic|noctalia)$ && "$expected" =~ ^[0-9a-f]{64}$ && -n "${statuses[$key]+x}" && -z "${removed[$key]+x}" && -z "${installed[$key]+x}" ]] || {
			warn "Journal de retirada generado inválido: $key"
			return 1
		}
		removed[$key]=$expected
	done <"$MIGRATION_DIR/generated-removed.tsv"

	# First decide every operation.  No generated target is touched until all
	# journal entries still describe either our bytes or their recorded preimage.
	for key in "${!installed[@]}"; do
		expected=${installed[$key]}
		status=${statuses[$key]}
		target="$(generated_target_path "$key")" || { failed=1; continue; }
		if [[ -f "$target" && ! -L "$target" ]]; then
			actual="$(sha256sum -- "$target" | cut -d' ' -f1)"
			if [[ "$actual" == "$expected" ]]; then
				remove_targets+=("$target")
				remove_after[$key]=1
		elif [[ "$status" == copy ]] && generated_snapshot_matches_target "$key" "$target"; then
				# Intent was checkpointed but mv had not happened yet.
				:
			else
				warn "No se sobrescribe un generado modificado después del despliegue: $target"
				failed=1
			fi
		elif [[ -L "$target" ]]; then
			if [[ "$status" == copy ]] && generated_snapshot_matches_target "$key" "$target"; then
				:
			elif [[ "$status" != legacy ]]; then
				warn "No se sobrescribe un destino generado con tipo inesperado: $target"
				failed=1
			fi
		elif [[ -e "$target" ]]; then
			warn "No se sobrescribe un destino generado con tipo inesperado: $target"
			failed=1
		fi
	done
	for key in "${!removed[@]}"; do
		expected=${removed[$key]}
		target="$(generated_target_path "$key")" || { failed=1; continue; }
		if [[ -f "$target" && ! -L "$target" ]]; then
			actual="$(sha256sum -- "$target" | cut -d' ' -f1)"
			if [[ "$actual" != "$expected" ]]; then
				warn "No se sobrescribe un generado recreado o modificado: $target"
				failed=1
			fi
		elif [[ -L "$target" || -e "$target" ]]; then
			warn "No se sobrescribe un destino generado con tipo inesperado: $target"
			failed=1
		fi
	done
	for key in "${!statuses[@]}"; do
		[[ -n "${installed[$key]+x}" || -n "${removed[$key]+x}" ]] || continue
		status=${statuses[$key]}
		[[ "$status" == copy ]] || continue
		target="$(generated_target_path "$key")" || { failed=1; continue; }
		snapshot="$MIGRATION_DIR/generated-backups/$key"
		[[ -e "$snapshot" || -L "$snapshot" ]] || { warn "Falta el snapshot generado: $key"; failed=1; continue; }
		if [[ -n "${remove_after[$key]+x}" ]] || { [[ ! -e "$target" && ! -L "$target" ]]; }; then
			restore_keys+=("$key")
		elif generated_snapshot_matches_target "$key" "$target"; then
			# The preimage never left HOME, or a prior rollback already restored it.
			:
		else
			warn "No se puede restaurar un destino generado ocupado: $target"
			failed=1
		fi
	done
	((failed == 0)) || return 1
	for target in "${remove_targets[@]}"; do
		if ! rm -f -- "$target"; then
			warn "No se pudo retirar el generado registrado: $target"
			return 1
		fi
	done
	for key in "${restore_keys[@]}"; do
		target="$(generated_target_path "$key")"
		snapshot="$MIGRATION_DIR/generated-backups/$key"
		if ! mkdir -p "$(dirname "$target")"; then
			warn "No se pudo crear el directorio de restauración generada: $target"
			return 1
		fi
		# Build the restored copy next to its final path, then replace atomically.
		local temporary
		if ! temporary="$(mktemp "$(dirname "$target")/.${key}.rollback.XXXXXX")"; then
			warn "No se pudo preparar la restauración generada: $target"
			return 1
		fi
		if ! rm -f -- "$temporary" || ! cp -a --no-dereference -- "$snapshot" "$temporary" || ! mv -fT -- "$temporary" "$target"; then
			warn "No se pudo restaurar el generado: $target"
			return 1
		fi
	done
}

generated_key_selected() {
	case "$1" in
	qmd) plan_has_bundle productivity-extra ;;
	restic) plan_has_bundle backup ;;
	noctalia) python3 -c 'import json,sys; raise SystemExit(json.load(open(sys.argv[1])).get("noctalia_configured") is not True)' "$PLAN_JSON" ;;
	*) return 1 ;;
	esac
}

generated_key_touched() {
	local key=$1
	grep -Eq "^${key}"$'\t' "$MIGRATION_DIR/generated-installed.tsv" ||
		grep -Eq "^${key}"$'\t' "$MIGRATION_DIR/generated-removed.tsv"
}

remove_deselected_generated_targets() {
	local key expected target actual failed=0
	while IFS=$'\t' read -r key expected; do
		[[ -n "$key" ]] || continue
		generated_key_selected "$key" && continue
		target="$(generated_target_path "$key")" || { failed=1; continue; }
		if [[ ! -f "$target" || -L "$target" ]]; then
			warn "No se retira un generado ausente o no regular: $target"
			failed=1
			continue
		fi
		actual="$(sha256sum -- "$target" | cut -d' ' -f1)"
		if [[ "$actual" != "$expected" ]]; then
			warn "No se retira un generado modificado por el usuario: $target"
			failed=1
			continue
		fi
		record_generated_intent "$MIGRATION_DIR/generated-removed.tsv" "$key" "$expected"
		if ! rm -- "$target"; then
			warn "No se pudo retirar el generado seleccionado: $target"
			failed=1
		fi
	done <"$MIGRATION_DIR/previous-generated-installed.tsv"
	return "$failed"
}

rollback_migration() {
	[[ -n "$MIGRATION_DIR" && -f "$MIGRATION_DIR/plan.json" && -f "$MIGRATION_DIR/legacy-modules" ]] || return 0
	if [[ -f "$MIGRATION_DIR/status" && $(<"$MIGRATION_DIR/status") == rolled-back ]]; then
		info "La transacción ya estaba restaurada: $MIGRATION_DIR"
		return 0
	fi
	warn "Restaurando transacción: $MIGRATION_DIR"
	local failed=0
	local -a restore_manifests=(
		"$MIGRATION_DIR/previous-restore-links.tsv"
		"$MIGRATION_DIR/legacy-links.tsv"
	)
	mapfile -t LEGACY_MODULES <"$MIGRATION_DIR/legacy-modules"
	if ! validate_restore_link_manifests "${restore_manifests[@]}"; then
		printf '%s\n' rollback-incomplete >"$MIGRATION_DIR/status"
		persist_migration_checkpoint
		warn "El rollback no puede restaurar enlaces de forma segura; conserva el snapshot: $MIGRATION_DIR"
		return 1
	fi
	if rollback_stow_checkpoint; then
		write_checkpoint_restored_links || failed=1
	else
		failed=1
	fi
	restore_generated_targets || failed=1
	restore_derived_state || failed=1
	restore_backup || failed=1
	if [[ -f "$MIGRATION_DIR/previous-links-removal-intent" || -f "$MIGRATION_DIR/previous-links-removed" ]]; then
		restore_removed_link_manifest \
			"$MIGRATION_DIR/previous-restore-links.tsv" \
			"$MIGRATION_DIR/previous-applied-links.tsv" \
			"$MIGRATION_DIR/previous-links-removed" || failed=1
	fi
	if [[ -f "$MIGRATION_DIR/legacy-links-removal-intent" || -f "$MIGRATION_DIR/legacy-links-removed" ]]; then
		restore_removed_link_manifest \
			"$MIGRATION_DIR/legacy-links.tsv" \
			"$MIGRATION_DIR/symlinks.tsv" \
			"$MIGRATION_DIR/legacy-links-removed" || failed=1
	fi
	if ! reload_user_manager 'durante el rollback'; then
		failed=1
	fi
	if ((failed)); then
		printf '%s\n' rollback-incomplete >"$MIGRATION_DIR/status"
		persist_migration_checkpoint
		warn "El rollback quedó incompleto; conserva el snapshot: $MIGRATION_DIR"
		return 1
	fi
	write_restored_active_links
	if ! write_restored_snapshot_links; then
		printf '%s\n' rollback-incomplete >"$MIGRATION_DIR/status"
		persist_migration_checkpoint
		warn "El rollback no pudo registrar sus snapshots privados: $MIGRATION_DIR"
		return 1
	fi
	write_restored_active_generated
	printf '%s\n' rolled-back >"$MIGRATION_DIR/status"
	persist_migration_checkpoint
	if ! reload_live_hyprland 'después del rollback'; then
		warn 'Los archivos anteriores se restauraron, pero la sesión Hyprland no pudo recargarlos.'
	fi
	ok "Transacción restaurada: $MIGRATION_DIR"
}

unstow_legacy_modules() {
	((${#LEGACY_MODULES[@]})) || return 0
	remove_link_manifest "$MIGRATION_DIR/symlinks.tsv" || die 'La retirada exacta de enlaces legacy falló; no se retiró ningún enlace.'
}

deploy_dotfiles() {
	# A later deployment may deselect optional bundles. Remove only the exact
	# links recorded by the last successful transaction, after a full manifest
	# check, so a user edit never causes a partial retirement.
	preflight_scheduled_link_removals || return 1
	record_link_removal_intent "$MIGRATION_DIR/previous-links-removal-intent" "$MIGRATION_DIR/previous-applied-links.tsv"
	remove_link_manifest "$MIGRATION_DIR/previous-applied-links.tsv"
	record_link_removal_complete "$MIGRATION_DIR/previous-links-removed" "$MIGRATION_DIR/previous-applied-links.tsv"
	record_link_removal_intent "$MIGRATION_DIR/legacy-links-removal-intent" "$MIGRATION_DIR/symlinks.tsv"
	unstow_legacy_modules
	record_link_removal_complete "$MIGRATION_DIR/legacy-links-removed" "$MIGRATION_DIR/symlinks.tsv"
	# Capture the complete pre-Stow state before the final simulation.  A link
	# that appears afterwards is then detected by the simulation as a conflict,
	# and the checkpoint knows it did not belong to this transaction.
	prepare_stow_checkpoint
	info "Simulando de nuevo tras crear la copia reversible..."
	if ! stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --simulate --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$HOME" "${PLAN_MODULES[@]}"; then
		return 1
	fi

	if ! stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$HOME" "${PLAN_MODULES[@]}"; then
		return 1
	fi
	verify_stow_checkpoint_applied || return 1
	ok "Dotfiles desplegados: ${PLAN_MODULES[*]}"
}

install_staged_file() {
	local key=$1 staged=$2 target temporary checksum actual
	[[ -s "$staged" ]] || die "Falta el artefacto generado para $key: $staged"
	target="$(generated_target_path "$key")" || die "Destino generado desconocido: $key"
	[[ ! -d "$target" || -L "$target" ]] || die "El destino generado es un directorio: $target"
	checksum="$(sha256sum -- "$staged" | cut -d' ' -f1)"
	record_generated_intent "$MIGRATION_DIR/generated-installed.tsv" "$key" "$checksum"
	if ! mkdir -p "$(dirname "$target")" || ! temporary="$(mktemp "$(dirname "$target")/.${key}.XXXXXX")"; then
		warn "No se pudo preparar la instalación generada: $target"
		return 1
	fi
	if ! install -m 600 -- "$staged" "$temporary"; then
		warn "No se pudo preparar el generado: $target"
		return 1
	fi
	actual="$(sha256sum -- "$temporary" | cut -d' ' -f1)"
	if [[ "$actual" != "$checksum" ]]; then
		warn "El artefacto generado cambió antes de instalarse: $target"
		return 1
	fi
	if ! mv -fT -- "$temporary" "$target"; then
		warn "No se pudo instalar el generado; queda su intención durable para rollback: $target"
		return 1
	fi
	ok "Configuración local instalada: $target"
}

install_staged_configs() {
	remove_deselected_generated_targets
	if plan_has_bundle productivity-extra; then
		install_staged_file qmd "$STATE_DIR/staged/qmd/index.yml"
	fi
	if plan_has_bundle backup; then
		install_staged_file restic "$STATE_DIR/staged/restic/repository"
	fi
	if generated_key_selected noctalia; then
		install_staged_file noctalia "$STATE_DIR/staged/noctalia/zz-host-overrides.toml"
	fi
}

generate_derived_state() {
	local -a resolver=(python3 "$HOST_TOOL" --repo "$DOTFILES_DIR" resolve --write --capabilities "$CAPABILITIES_JSON")
	[[ -n "$HOST_CONFIG" ]] && resolver+=(--host-config "$HOST_CONFIG")
	((SAFE_DEFAULTS)) && resolver+=(--safe-defaults)
	record_derived_mutation_intent
	if ! "${resolver[@]}" >/dev/null; then
		# The resolver writes each derived file atomically, but may have completed
		# a prefix. Record that exact prefix so rollback can restore the snapshot.
		record_derived_state
		return 1
	fi
	record_derived_state
}

validate_deployed_config() {
	stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --simulate \
		--dir "$DOTFILES_DIR" --target "$HOME" "${PLAN_MODULES[@]}" >/dev/null
	if command -v Hyprland >/dev/null 2>&1 && [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
		DOTFILES_GENERATED_HYPR_DIR="$STATE_DIR/generated/hypr" \
			Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" >/dev/null
	fi
	if command -v noctalia >/dev/null 2>&1 && [[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/noctalia" ]]; then
		noctalia config validate "${XDG_CONFIG_HOME:-$HOME/.config}/noctalia" >/dev/null
	fi
	if command -v kanata >/dev/null 2>&1 && [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/kanata/config.kbd" ]]; then
		kanata --check -c "${XDG_CONFIG_HOME:-$HOME/.config}/kanata/config.kbd" >/dev/null
	fi
}

user_manager_available() {
	command -v systemctl >/dev/null 2>&1 || return 1
	systemctl --user show-environment >/dev/null 2>&1
}

reload_user_manager() {
	local context=${1:-'después del despliegue'}
	if ! command -v systemctl >/dev/null 2>&1; then
		info 'systemctl no está disponible; las unidades se cargarán cuando exista una sesión systemd de usuario.'
		return 0
	fi
	if ! user_manager_available; then
		info 'No hay un gestor systemd de usuario accesible; las unidades se cargarán en la próxima sesión.'
		return 0
	fi
	if ! systemctl --user daemon-reload; then
		warn "No se pudo recargar systemd de usuario $context."
		return 1
	fi
}

configure_user_services() {
	command -v jq >/dev/null 2>&1 || { warn 'jq no está disponible; no se puede reconciliar el servicio de audio.'; return 1; }
	if ! user_manager_available; then
		info 'No hay un gestor systemd de usuario accesible; el enrutado de audio se reconciliará en la próxima sesión.'
		return 0
	fi
	if jq -e '.audio.auto_route == true' "$PLAN_JSON" >/dev/null 2>&1; then
		if systemctl --user restart audio-route-manager.service; then
			ok 'Enrutado automático de audio activo.'
			return 0
		fi
		warn 'No se pudo iniciar audio-route-manager.service después del despliegue.'
		return 1
	fi
	systemctl --user stop audio-route-manager.service >/dev/null 2>&1 || true
}

reload_live_hyprland() {
	local context=${1:-'después del despliegue'}
	local expected_description=${2:-}
	local config_errors binds_json
	if ! command -v hyprctl >/dev/null 2>&1; then
		return 0
	fi
	if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
		info 'No hay una sesión Hyprland accesible; la configuración se cargará en el próximo inicio de sesión.'
		return 0
	fi
	if ! hyprctl reload >/dev/null 2>&1; then
		warn "No se pudo recargar Hyprland $context."
		return 1
	fi
	if ! config_errors="$(hyprctl configerrors 2>/dev/null)"; then
		warn "No se pudo consultar el estado de Hyprland $context."
		return 1
	fi
	if [[ -n ${config_errors//[[:space:]]/} ]]; then
		warn "Hyprland informa de errores de configuración $context."
		return 1
	fi
	if [[ -n "$expected_description" ]]; then
		if ! binds_json="$(hyprctl binds -j 2>/dev/null)"; then
			warn "No se pudieron comprobar los atajos de Hyprland $context."
			return 1
		fi
		if ! python3 -c '
import json
import sys

binds = json.load(sys.stdin)
expected = sys.argv[1]
valid = isinstance(binds, list) and any(
    isinstance(bind, dict) and bind.get("description") == expected for bind in binds
)
raise SystemExit(0 if valid else 1)
' "$expected_description" <<<"$binds_json"; then
			warn "Hyprland no registró el atajo gestionado esperado $context."
			return 1
		fi
	fi
	ok "Sesión Hyprland recargada $context."
}

apply_dotfiles_transaction() {
	begin_migration
	if ! (
		set -euo pipefail
		# Bash suppresses errexit when this subshell is the condition of `if !`.
		# Guard every phase explicitly so a failed preflight can never fall through
		# into generated state, HOME moves, Stow, validation or service changes.
		preflight_migration_checkout_links || exit 1
		generate_derived_state || exit 1
		backup_targets || exit 1
		deploy_dotfiles || exit 1
		install_staged_configs || exit 1
		validate_deployed_config || exit 1
		reload_user_manager 'después del despliegue' || exit 1
	); then
		if rollback_migration; then
			die 'El despliegue falló y se restauró el estado anterior.'
		fi
		die "El despliegue y su rollback fallaron. Conserva el snapshot: $MIGRATION_DIR"
	fi
	printf '%s\n' applied >"$MIGRATION_DIR/status"
	persist_migration_checkpoint
	printf '%s\n' "$MIGRATION_DIR" >"$STATE_DIR/last-migration"
	sync -f -- "$STATE_DIR/last-migration" || die 'No se pudo sincronizar la referencia de la migración aplicada.'
	sync -f -- "$STATE_DIR" || die 'No se pudo sincronizar el estado de migración aplicado.'
	sync -f -- "$(dirname "$STATE_DIR")" || die 'No se pudo sincronizar el índice del estado aplicado.'
	if ! reload_live_hyprland 'después del despliegue' 'Open Ghostty'; then
		warn 'Los archivos se aplicaron y validaron, pero la sesión Hyprland no aceptó la recarga final.'
	fi
	ok "Transacción aplicada: $MIGRATION_DIR"
}

configure_thunderbird_dynamic_theme() {
	local setup="$HOME/.local/bin/setup-thunderbird-project-atlas-theme"
	local generated_policy="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/thunderbird/policies.json"
	local installed_policy=/etc/thunderbird/policies/policies.json

	command -v thunderbird >/dev/null 2>&1 || return 0
	[[ -x $setup ]] || { warn 'Thunderbird está instalado, pero falta el generador de su tema dinámico.'; return 0; }
	if ! "$setup" >/dev/null; then
		warn 'No se pudo generar la extensión de tema dinámico de Thunderbird.'
		return 0
	fi
	if cmp -s -- "$generated_policy" "$installed_policy"; then
		ok 'Tema dinámico de Thunderbird preparado.'
	else
		warn "La extensión está preparada, pero falta aplicar su política: pkexec install -D -m 644 '$generated_policy' '$installed_policy'"
	fi
}

main() {
	# Stow modela .config dentro de HOME. Rechaza un layout dividido antes de
	# detectar, configurar, instalar paquetes o crear estado local.
	validate_xdg_config_layout
	parse_args "$@"
	validate_manifest
	if ((LIST_PACKAGES)); then
		list_packages
		exit 0
	fi

	check_prerequisites
	validate_plan_modules
	# Inspect the exact live composition before querying package availability.
	# A changed prior link must fail here, before any later installation path can
	# start, and --check still performs the package/compatibility report below.
	check_dotfiles
	check_packages
	check_runtime_compatibility available
	if plan_has_module codex; then
		"$DOTFILES_DIR/scripts/migrate-codex-skill-paths.sh" --check
		"$DOTFILES_DIR/scripts/manage-codex-skill-links.sh" --check
	fi
	if ((CHECK_ONLY)); then
		ok "Validación terminada sin cambios."
		exit 0
	fi

	printf '\nComposición: %s\nDestino dotfiles: %s\n' "$(tr '\n' ' ' < <(python3 -c 'import json,sys; print(*json.load(open(sys.argv[1]))["bundles"], sep="\n")' "$PLAN_JSON"))" "$HOME"
	printf '%s\n' 'Si falta algún paquete, Shelly actualizará CachyOS por completo antes de instalarlo; Flatpak gestionará aplicaciones del usuario. Esos cambios no forman parte del backup de HOME.'
	printf 'No se desplegará system-etc ni se cambiarán explícitamente GPU, arranque, Btrfs o zram. ¿Continuar? [s/N] '
	read -r answer
	[[ "$answer" =~ ^[sS]$ ]] || exit 0

	install_packages
	check_runtime_compatibility installed
	# Los binarios nuevos validan una copia temporal antes de que Stow toque HOME.
	validate_resolved_runtime 1
	install_flatpaks
	mkdir -p "$STATE_DIR"
	apply_dotfiles_transaction
	configure_user_services || true
	configure_thunderbird_dynamic_theme
	if plan_has_module codex; then
		"$DOTFILES_DIR/scripts/migrate-codex-skill-paths.sh" --apply
		"$DOTFILES_DIR/scripts/manage-codex-skill-links.sh" --apply
	fi
	command -v fc-cache >/dev/null && fc-cache -f
	ok "Instalación terminada. Reinicia la sesión si cambiaste teclado o shell."
}

if [[ ${DOTFILES_INSTALL_SOURCE_ONLY:-0} != 1 ]]; then
	main "$@"
fi
