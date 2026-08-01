#!/usr/bin/env bash
set -euo pipefail

# Bootstrap reproducible para CachyOS/Noctalia.
# No modifica GPU, initramfs, arranque, Btrfs, zram, firewall ni /etc.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR
readonly PACKAGES_CSV="$DOTFILES_DIR/packages.csv"
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
BACKUP_DIR="$STATE_DIR/backups/workstation-$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_DIR
readonly -a WORKSTATION_MODULES=(
	codex fish fonts ghostty git hypr-laptop kanata mimeapps
	noctalia nvim shell starship vscode zellij
)

CHECK_ONLY=0

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[AVISO]\033[0m %s\n' "$*"; }
die() {
	printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Uso:
  ./install.sh workstation [--check]

  workstation  instala exclusivamente el perfil de trabajo permitido
  --check      valida paquetes y simula Stow sin modificar el sistema ni HOME

Los módulos de system-etc se gestionan aparte con just check-system/apply-system.
EOF
}

parse_args() {
	(($# > 0)) || {
		usage
		exit 2
	}

	local profile=''
	while (($#)); do
		case "$1" in
		workstation)
			[[ -z "$profile" ]] || die "Solo se admite un perfil."
			profile=$1
			;;
		--check)
			CHECK_ONLY=1
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

	[[ "$profile" == workstation ]] || die "Especifica el perfil workstation."
}

check_prerequisites() {
	[[ $EUID -ne 0 ]] || die "Ejecuta el instalador como usuario normal, no como root."
	command -v pacman >/dev/null || die "Esta configuración requiere Arch o CachyOS."
	command -v git >/dev/null || die "Instala primero git y base-devel con Pacman o Shelly."
	command -v stow >/dev/null || die "Instala primero GNU Stow con Pacman o Shelly."
	command -v shelly >/dev/null || die "Shelly no está instalado; usa el paquete oficial de CachyOS."
	[[ -f "$PACKAGES_CSV" ]] || die "No existe $PACKAGES_CSV."
}

validate_manifest() {
	local invalid=0
	local category package source extra

	while IFS=, read -r category package source extra; do
		[[ -n "$category" && -n "$package" && -n "$source" && -z "${extra:-}" ]] || {
			warn "Fila inválida en packages.csv: ${category:-?},${package:-?},${source:-?}"
			invalid=1
			continue
		}
		[[ "$source" == native || "$source" == aur ]] || {
			warn "Origen no permitido para $package: $source"
			invalid=1
		}
		[[ "$category" != gaming ]] || {
			warn "La categoría gaming no pertenece al perfil workstation."
			invalid=1
		}
		if [[ "$package" =~ (^|-)nvidia($|-) || "$package" =~ ^(steam|lutris|heroic|gamescope) ]]; then
			warn "Paquete excluido del bootstrap (GPU/gaming): $package"
			invalid=1
		fi
	done <"$PACKAGES_CSV"

	((invalid == 0)) || die "Corrige packages.csv antes de continuar."

	local module
	for module in "${WORKSTATION_MODULES[@]}"; do
		[[ "$module" != system-etc ]] || die "system-etc nunca puede desplegarse en HOME."
		[[ -d "$DOTFILES_DIR/$module" ]] || die "No existe el módulo Stow: $module"
	done
}

collect_packages() {
	local source=$1
	awk -F, -v source="$source" '$3 == source { print $2 }' "$PACKAGES_CSV" | sort -u
}

check_packages() {
	local -a native_packages aur_packages missing
	mapfile -t native_packages < <(collect_packages native)
	mapfile -t aur_packages < <(collect_packages aur)

	info "Validando ${#native_packages[@]} paquetes de repositorios..."
	missing=()
	local package
	for package in "${native_packages[@]}"; do
		pacman -Si "$package" >/dev/null 2>&1 || missing+=("$package")
	done
	((${#missing[@]} == 0)) || die "Paquetes nativos no encontrados: ${missing[*]}"

	printf 'Paquetes nativos: %s\n' "${native_packages[*]}"
	printf 'Paquetes AUR (revisión de Shelly): %s\n' "${aur_packages[*]}"
}

install_packages() {
	local -a native_packages aur_packages
	mapfile -t native_packages < <(collect_packages native)
	mapfile -t aur_packages < <(collect_packages aur)

	if ((${#native_packages[@]})); then
		shelly install standard "${native_packages[@]}"
	fi
	if ((${#aur_packages[@]})); then
		warn "Shelly mostrará la procedencia de los paquetes AUR antes de instalarlos."
		shelly install aur "${aur_packages[@]}"
	fi
}

check_dotfiles() {
	info "Simulación verbosa de Stow para workstation..."
	stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --simulate --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$HOME" "${WORKSTATION_MODULES[@]}"
}

is_private_env_path() {
	local relative=$1
	[[ "$relative" == .env* || "$relative" == */.env* ]]
}

is_vendored_atlas_skill() {
	local relative=$1
	[[ "$relative" == .agents/skills/frontend-task/* ||
		"$relative" == .agents/skills/reuse-first/* ||
		"$relative" == .agents/skills/visual-direction/* ]]
}

is_stow_ignored_path() {
	local module=$1 relative=$2
	is_private_env_path "$relative" && return 0
	[[ "${relative##*/}" == .stow-local-ignore ]] && return 0
	[[ "$module" == codex ]] && is_vendored_atlas_skill "$relative" && return 0
	[[ "$module" == shell && "$relative" == .local/bin/btrfs-snapshots ]] && return 0
	return 1
}

tracked_module_sources() {
	local module=$1 tracked source
	while IFS= read -r -d '' tracked; do
		source="$DOTFILES_DIR/$tracked"
		[[ -f "$source" || -L "$source" ]] && printf '%s\0' "$source"
	done < <(git -C "$DOTFILES_DIR" ls-files -z -- "$module")
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

backup_targets() {
	mkdir -p "$BACKUP_DIR"
	local module source relative target
	local backed_up=0

	# No atraviesa enlaces de directorio: mover un hijo modificaría su origen real.
	for module in "${WORKSTATION_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			target="$HOME/$relative"
			[[ -e "$target" || -L "$target" ]] || continue
			target_is_managed_dotfile "$target" && continue
			if target_has_symlink_parent "$target"; then
				die "Destino bajo un directorio enlazado; revísalo manualmente: $target"
			fi
		done < <(tracked_module_sources "$module")
	done

	for module in "${WORKSTATION_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			target="$HOME/$relative"

			if [[ ! -e "$target" && ! -L "$target" ]]; then
				continue
			fi
			target_is_managed_dotfile "$target" && continue

			mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
			mv "$target" "$BACKUP_DIR/$relative"
			printf '%s\n' "$relative" >>"$BACKUP_DIR/manifest.txt"
			backed_up=1
		done < <(tracked_module_sources "$module")
	done

	if ((backed_up)); then
		printf '%s\n' "$BACKUP_DIR" >"$STATE_DIR/last-backup"
		ok "Copia reversible: $BACKUP_DIR"
	else
		rmdir "$BACKUP_DIR"
		info "No había destinos ajenos que respaldar."
	fi
}

restore_backup() {
	[[ -f "$BACKUP_DIR/manifest.txt" ]] || return 0
	warn "Stow falló; restaurando los destinos respaldados..."

	local relative backup target
	while IFS= read -r relative; do
		backup="$BACKUP_DIR/$relative"
		target="$HOME/$relative"
		[[ -e "$backup" || -L "$backup" ]] || continue
		[[ ! -e "$target" && ! -L "$target" ]] || continue
		mkdir -p "$(dirname "$target")"
		mv "$backup" "$target"
	done <"$BACKUP_DIR/manifest.txt"
}

deploy_dotfiles() {
	info "Simulando de nuevo tras crear la copia reversible..."
	if ! stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --simulate --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$HOME" "${WORKSTATION_MODULES[@]}"; then
		restore_backup
		die "La simulación de Stow falló; no se desplegaron dotfiles."
	fi

	if ! stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$HOME" "${WORKSTATION_MODULES[@]}"; then
		restore_backup
		die "Stow falló y se intentó restaurar la copia previa."
	fi
	ok "Dotfiles desplegados: ${WORKSTATION_MODULES[*]}"
}

main() {
	parse_args "$@"
	check_prerequisites
	validate_manifest
	check_packages

	if ((CHECK_ONLY)); then
		check_dotfiles
		ok "Validación terminada sin cambios."
		exit 0
	fi

	printf '\nPerfil: workstation\nDestino dotfiles: %s\n' "$HOME"
	printf 'No se tocarán /etc, GPU, arranque, Btrfs ni zram. ¿Continuar? [s/N] '
	read -r answer
	[[ "$answer" =~ ^[sS]$ ]] || exit 0

	install_packages
	mkdir -p "$STATE_DIR"
	backup_targets
	deploy_dotfiles
	command -v fc-cache >/dev/null && fc-cache -f
	ok "Instalación terminada. Reinicia la sesión si cambiaste teclado o shell."
}

main "$@"
