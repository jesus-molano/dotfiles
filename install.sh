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
readonly PROFILES_FILE="$DOTFILES_DIR/profiles.sh"
[[ -f "$PROFILES_FILE" ]] || {
	printf 'No existe la definición de perfiles: %s\n' "$PROFILES_FILE" >&2
	exit 1
}
# shellcheck source=profiles.sh
source "$PROFILES_FILE"
declare -a PROFILE_MODULES=()
PROFILE=''
BACKUP_DIR=''

CHECK_ONLY=0
LIST_PACKAGES=0

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
  ./install.sh {workstation|desktop} [--check|--list-packages]

  workstation  módulos comunes y hardware del portátil
  desktop      módulos comunes, hardware del sobremesa y gaming
  --check      valida manifiestos/paquetes y simula Stow sin modificar el sistema ni HOME
  --list-packages
               lista un paquete o app ID por línea sin modificar el sistema ni HOME

Los módulos de system-etc se gestionan aparte con just check-system/apply-system.
EOF
}

parse_args() {
	(($# > 0)) || {
		usage
		exit 2
	}

	while (($#)); do
		case "$1" in
		workstation | desktop)
			[[ -z "$PROFILE" ]] || die "Solo se admite un perfil."
			PROFILE=$1
			;;
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

	[[ -n "$PROFILE" ]] || die "Especifica el perfil workstation o desktop."
	if ((CHECK_ONLY && LIST_PACKAGES)); then
		die "--check y --list-packages no se pueden combinar."
	fi
	mapfile -t PROFILE_MODULES < <(profile_modules "$PROFILE")
	BACKUP_DIR="$STATE_DIR/backups/$PROFILE-$(date +%Y%m%d-%H%M%S)"
}

check_prerequisites() {
	[[ $EUID -ne 0 ]] || die "Ejecuta el instalador como usuario normal, no como root."
	command -v pacman >/dev/null || die "Esta configuración requiere Arch o CachyOS."
	command -v git >/dev/null || die "Instala primero git y base-devel con Pacman o Shelly."
	command -v stow >/dev/null || die "Instala primero GNU Stow con Pacman o Shelly."
	command -v shelly >/dev/null || die "Shelly no está instalado; usa el paquete oficial de CachyOS."
}

scope_is_valid() {
	[[ "${1:-}" == common || "${1:-}" == desktop || "${1:-}" == workstation ]]
}

validate_package_manifest() {
	local invalid=0
	local scope category package source extra duplicates
	[[ -f "$PACKAGES_CSV" ]] || die "No existe $PACKAGES_CSV."

	while IFS=, read -r scope category package source extra; do
		[[ -n "$scope" && "$category" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ &&
			"$package" =~ ^[A-Za-z0-9][A-Za-z0-9@+._-]*$ &&
			-n "$source" && -z "${extra:-}" ]] || {
			warn "Fila inválida en packages.csv: ${scope:-?},${category:-?},${package:-?},${source:-?}"
			invalid=1
			continue
		}
		scope_is_valid "$scope" || {
			warn "Ámbito no permitido para $package: $scope"
			invalid=1
		}
		[[ "$source" == native || "$source" == aur ]] || {
			warn "Origen no permitido para $package: $source"
			invalid=1
		}
		if [[ "$package" =~ (^|-)nvidia($|-) ]]; then
			warn "Paquete GPU administrado por CHWD y excluido del bootstrap: $package"
			invalid=1
		fi
	done <"$PACKAGES_CSV"

	duplicates="$(cut -d, -f3 "$PACKAGES_CSV" | sort | uniq -d)"
	if [[ -n "$duplicates" ]]; then
		warn "Paquetes duplicados en packages.csv: ${duplicates//$'\n'/ }"
		invalid=1
	fi
	((invalid == 0)) || die "Corrige packages.csv antes de continuar."
}

validate_flatpak_manifests() {
	local invalid=0
	local remote url remote_extra scope category app_id branch app_extra duplicates duplicate_remotes
	[[ -f "$FLATPAK_REMOTES_CSV" ]] || die "No existe $FLATPAK_REMOTES_CSV."
	[[ -f "$FLATPAKS_CSV" ]] || die "No existe $FLATPAKS_CSV."

	while IFS=, read -r remote url remote_extra; do
		[[ "$remote" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ &&
			"$url" =~ ^https:// && -z "${remote_extra:-}" ]] || {
			warn "Remoto Flatpak inválido: ${remote:-?},${url:-?}"
			invalid=1
		}
	done <"$FLATPAK_REMOTES_CSV"
	duplicate_remotes="$(cut -d, -f1 "$FLATPAK_REMOTES_CSV" | sort | uniq -d)"
	if [[ -n "$duplicate_remotes" ]]; then
		warn "Remotos duplicados en flatpak-remotes.csv: ${duplicate_remotes//$'\n'/ }"
		invalid=1
	fi

	while IFS=, read -r scope category app_id remote branch app_extra; do
		[[ -n "$scope" && -n "$category" &&
			"$app_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ &&
			"$remote" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ &&
			"$branch" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ &&
			-z "${app_extra:-}" ]] || {
			warn "Aplicación Flatpak inválida: ${scope:-?},${category:-?},${app_id:-?},${remote:-?},${branch:-?}"
			invalid=1
			continue
		}
		scope_is_valid "$scope" || {
			warn "Ámbito Flatpak no permitido para $app_id: $scope"
			invalid=1
		}
		awk -F, -v requested="$remote" '$1 == requested { found = 1 } END { exit !found }' \
			"$FLATPAK_REMOTES_CSV" || {
			warn "Remoto Flatpak no declarado para $app_id: $remote"
			invalid=1
		}
	done <"$FLATPAKS_CSV"

	duplicates="$(cut -d, -f3 "$FLATPAKS_CSV" | sort | uniq -d)"
	if [[ -n "$duplicates" ]]; then
		warn "Aplicaciones duplicadas en flatpaks.csv: ${duplicates//$'\n'/ }"
		invalid=1
	fi
	((invalid == 0)) || die "Corrige los manifiestos Flatpak antes de continuar."
}

validate_manifest() {
	validate_package_manifest
	validate_flatpak_manifests
}

validate_profile_modules() {
	local module
	for module in "${PROFILE_MODULES[@]}"; do
		[[ "$module" != system-etc ]] || die "system-etc nunca puede desplegarse en HOME."
		[[ -d "$DOTFILES_DIR/$module" ]] || die "No existe el módulo Stow: $module"
	done
}

collect_packages() {
	local source=$1
	awk -F, -v profile="$PROFILE" -v source="$source" \
		'$4 == source && ($1 == "common" || $1 == profile) { print $3 }' \
		"$PACKAGES_CSV" | sort -u
}

collect_flatpaks() {
	awk -F, -v profile="$PROFILE" \
		'$1 == "common" || $1 == profile { print $3 "," $4 "," $5 }' \
		"$FLATPAKS_CSV" | sort -u
}

flatpak_remote_url() {
	local requested=$1
	awk -F, -v requested="$requested" '$1 == requested { print $2; exit }' \
		"$FLATPAK_REMOTES_CSV"
}

list_packages() {
	{
		collect_packages native
		collect_packages aur
		collect_flatpaks | cut -d, -f1
	} | sort -u
}

check_flatpaks() {
	local -a flatpaks=()
	mapfile -t flatpaks < <(collect_flatpaks)
	((${#flatpaks[@]})) || return 0

	printf 'Aplicaciones Flatpak declaradas: %s\n' "${#flatpaks[@]}"
	if ! command -v flatpak >/dev/null 2>&1; then
		warn "Flatpak aún no está instalado; su paquete nativo se instalará antes que las aplicaciones."
		return 0
	fi

	local spec app_id remote branch metadata
	for spec in "${flatpaks[@]}"; do
		IFS=, read -r app_id remote branch <<<"$spec"
		if ! flatpak remotes --columns=name 2>/dev/null | grep -Fxq -- "$remote"; then
			warn "El remoto $remote no está configurado; se añadirá para el usuario al aplicar."
			continue
		fi
		if ! metadata="$(flatpak remote-info "$remote" "$app_id//$branch" 2>&1)"; then
			printf '%s\n' "$metadata" >&2
			die "Flatpak no disponible: $app_id//$branch en $remote."
		fi
		info "Flatpak disponible: $app_id//$branch ($remote)"
	done
}

check_packages() {
	local -a native_packages aur_packages
	mapfile -t native_packages < <(collect_packages native)
	mapfile -t aur_packages < <(collect_packages aur)

	info "Validando ${#native_packages[@]} paquetes de repositorios..."
	local package_metadata
	if ! package_metadata="$(pacman -Si "${native_packages[@]}" 2>&1)"; then
		printf '%s\n' "$package_metadata" >&2
		die "Hay paquetes nativos no disponibles en los repositorios configurados."
	fi

	printf 'Paquetes nativos: %s\n' "${native_packages[*]}"
	printf 'Paquetes AUR (revisión de Shelly): %s\n' "${aur_packages[*]}"
	check_flatpaks
}

install_packages() {
	local -a native_packages aur_packages missing_native=()
	mapfile -t native_packages < <(collect_packages native)
	mapfile -t aur_packages < <(collect_packages aur)

	local package
	for package in "${native_packages[@]}"; do
		pacman -Q "$package" >/dev/null 2>&1 || missing_native+=("$package")
	done
	if ((${#missing_native[@]})); then
		if command -v pkexec >/dev/null 2>&1 &&
			[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
			info "Polkit instalará los paquetes nativos que faltan."
			pkexec /usr/bin/shelly install standard --no-confirm "${missing_native[@]}"
		else
			warn "Polkit gráfico no está disponible; Shelly solicitará sudo en la terminal."
			shelly install standard "${missing_native[@]}"
		fi
	else
		info "Todos los paquetes nativos ya están instalados."
	fi
	if ((${#aur_packages[@]})); then
		warn "Shelly mostrará la procedencia de cada paquete AUR antes de instalarlo."
		for package in "${aur_packages[@]}"; do
			if pacman -Q "$package" >/dev/null 2>&1; then
				info "Paquete AUR ya instalado: $package"
				continue
			fi
			warn "El AUR se compila como usuario; Shelly puede solicitar sudo solo para instalar el paquete construido."
			info "Instalando paquete AUR: $package"
			shelly install aur "$package" || die "Falló la instalación AUR de $package."
		done
	fi
}

install_flatpaks() {
	local -a flatpaks=()
	mapfile -t flatpaks < <(collect_flatpaks)
	((${#flatpaks[@]})) || return 0
	command -v flatpak >/dev/null 2>&1 || die "Flatpak no quedó instalado tras la transacción de paquetes nativos."

	local spec app_id remote branch remote_url
	for spec in "${flatpaks[@]}"; do
		IFS=, read -r app_id remote branch <<<"$spec"
		remote_url="$(flatpak_remote_url "$remote")"
		[[ -n "$remote_url" ]] || die "No hay URL declarada para el remoto Flatpak $remote."
		flatpak remote-add --user --if-not-exists "$remote" "$remote_url" ||
			die "No se pudo configurar el remoto Flatpak $remote para el usuario."
		if flatpak info --user "$app_id//$branch" >/dev/null 2>&1; then
			info "Flatpak ya instalado para el usuario: $app_id//$branch"
			continue
		fi
		info "Instalando Flatpak para el usuario: $app_id//$branch ($remote)"
		flatpak install --user --noninteractive --assumeyes "$remote" "$app_id//$branch" ||
			die "Falló la instalación Flatpak de $app_id//$branch."
	done
}

check_dotfiles() {
	validate_target_safety
	report_legacy_targets
	report_backup_targets
	info "Simulación verbosa de Stow para $PROFILE (los destinos listados se respaldarían)..."
	# --adopt solo permite modelar los destinos que el despliegue moverá al backup.
	# --simulate garantiza que ni HOME ni las fuentes del repositorio cambian.
	stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --adopt --simulate --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$HOME" "${PROFILE_MODULES[@]}"
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
	printf 'BACKUP: %s (migración NVIDIA a desktop)\n' \
		"$HOME/.config/fish/functions/dgpu.fish"
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

module_sources() {
	local module=$1
	find "$DOTFILES_DIR/$module" \( -type f -o -type l \) -print0
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
	for module in "${PROFILE_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
			target="$HOME/$relative"
			[[ -e "$target" || -L "$target" ]] || continue
			target_is_managed_dotfile "$target" && continue
			if target_has_symlink_parent "$target"; then
				die "Destino bajo un directorio enlazado; revísalo manualmente: $target"
			fi
		done < <(module_sources "$module")
	done
}

report_backup_targets() {
	local module source relative target
	for module in "${PROFILE_MODULES[@]}"; do
		while IFS= read -r -d '' source; do
			relative=${source#"$DOTFILES_DIR/$module/"}
			is_stow_ignored_path "$module" "$relative" && continue
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
	if legacy_dgpu_target_is_managed; then
		relative=.config/fish/functions/dgpu.fish
		target="$HOME/$relative"
		mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
		mv "$target" "$BACKUP_DIR/$relative"
		printf '%s\n' "$relative" >>"$BACKUP_DIR/manifest.txt"
		backed_up=1
	fi

	for module in "${PROFILE_MODULES[@]}"; do
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
		--dir "$DOTFILES_DIR" --target "$HOME" "${PROFILE_MODULES[@]}"; then
		restore_backup
		die "La simulación de Stow falló; no se desplegaron dotfiles."
	fi

	if ! stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --verbose=2 \
		--dir "$DOTFILES_DIR" --target "$HOME" "${PROFILE_MODULES[@]}"; then
		restore_backup
		die "Stow falló y se intentó restaurar la copia previa."
	fi
	ok "Dotfiles desplegados ($PROFILE): ${PROFILE_MODULES[*]}"
}

main() {
	parse_args "$@"
	validate_manifest
	if ((LIST_PACKAGES)); then
		list_packages
		exit 0
	fi

	check_prerequisites
	validate_profile_modules
	check_packages

	if ((CHECK_ONLY)); then
		check_dotfiles
		ok "Validación terminada sin cambios."
		exit 0
	fi

	printf '\nPerfil: %s\nDestino dotfiles: %s\n' "$PROFILE" "$HOME"
	printf '%s\n' 'Shelly modificará paquetes globales y Flatpak gestionará aplicaciones del usuario; esos cambios no forman parte del backup de HOME.'
	printf 'No se desplegará system-etc ni se cambiarán explícitamente GPU, arranque, Btrfs o zram. ¿Continuar? [s/N] '
	read -r answer
	[[ "$answer" =~ ^[sS]$ ]] || exit 0

	install_packages
	install_flatpaks
	mkdir -p "$STATE_DIR"
	backup_targets
	deploy_dotfiles
	command -v fc-cache >/dev/null && fc-cache -f
	ok "Instalación terminada. Reinicia la sesión si cambiaste teclado o shell."
}

main "$@"
