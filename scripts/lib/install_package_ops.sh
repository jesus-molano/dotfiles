#!/usr/bin/env bash
# shellcheck shell=bash

# Contratos de manifiestos, resolución e instalación de paquetes.
# install.sh define las rutas, el plan y las funciones de salida que usa esta biblioteca.
scope_is_valid() {
	[[ "${1:-}" =~ ^base$|^bundle:(gaming-core|gaming-launchers|gaming-tools|backup|rgb-openrgb|local-ai|productivity-extra)$ ]]
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

validate_plan_modules() {
	local module
	for module in "${PLAN_MODULES[@]}"; do
		[[ "$module" != system-etc ]] || die "system-etc nunca puede desplegarse en HOME."
		[[ -d "$DOTFILES_DIR/$module" ]] || die "No existe el módulo Stow: $module"
	done
}
collect_packages() {
	local source=$1
	local scopes
	scopes="$(IFS='|'; printf '%s' "${PACKAGE_SCOPES[*]}")"
	awk -F, -v scopes="$scopes" -v source="$source" \
		'BEGIN { split(scopes, selected, "|"); for (i in selected) allowed[selected[i]]=1 } $4 == source && allowed[$1] { print $3 }' \
		"$PACKAGES_CSV" | sort -u
}

collect_flatpaks() {
	local scopes
	scopes="$(IFS='|'; printf '%s' "${PACKAGE_SCOPES[*]}")"
	awk -F, -v scopes="$scopes" \
		'BEGIN { split(scopes, selected, "|"); for (i in selected) allowed[selected[i]]=1 } allowed[$1] { print $3 "," $4 "," $5 }' \
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
		if ! flatpak remotes --user --columns=name 2>/dev/null | grep -Fxq -- "$remote"; then
			warn "El remoto $remote no está configurado; se añadirá para el usuario al aplicar."
			continue
		fi
		if ! metadata="$(flatpak remote-info --user "$remote" "$app_id//$branch" 2>&1)"; then
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

compatibility_requirements() {
	python3 - "$PLAN_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    packages = json.load(stream).get("compatibility", {}).get("packages", {})
for package, requirement in sorted(packages.items()):
    print(
        package,
        requirement["minimum"],
        requirement.get("stable_minimum", "-"),
        requirement["source"],
        sep="\t",
    )
PY
}

check_runtime_compatibility() {
	local mode=${1:-available} package minimum stable_minimum source version floor comparison
	[[ "$mode" == available || "$mode" == installed ]] || die "Modo de compatibilidad inválido: $mode"
	while IFS=$'\t' read -r package minimum stable_minimum source; do
		[[ -n "$package" ]] || continue
		version=''
		if version="$(pacman -Q "$package" 2>/dev/null | awk 'NR == 1 { print $2 }')" && [[ -n "$version" ]]; then
			:
		elif [[ "$mode" == available && "$source" == native ]]; then
			version="$(pacman -Sp --print-format '%v' "$package" 2>/dev/null | sed -n '1p')"
			[[ -n "$version" ]] || die "No se pudo resolver una versión candidata de $package."
		elif [[ "$mode" == available && "$source" == aur ]]; then
			info "Compatibilidad de $package diferida hasta que Shelly compile el paquete AUR."
			continue
		else
			die "Falta el runtime requerido: $package >= $minimum."
		fi
		floor=$minimum
		# Pacman ordena 5.0.0 por debajo de 5.0.0_beta.9. El contrato
		# puede declarar un suelo alternativo para la rama estable sin relajar
		# el mínimo de las betas que siguen usando ese esquema de versión.
		if [[ "$stable_minimum" != - && "$version" != *_beta.* ]]; then
			floor=$stable_minimum
		fi
		comparison="$(vercmp "$version" "$floor")"
		[[ "$comparison" =~ ^-?[0-9]+$ ]] || die "No se pudo comparar la versión de $package."
		((comparison >= 0)) || die "$package $version es anterior al mínimo compatible $floor. Actualiza CachyOS por completo y repite la instalación."
		info "Compatibilidad: $package $version >= $floor"
	done < <(compatibility_requirements)
}

validate_resolved_runtime() {
	local required=${1:-0}
	DOTFILES_REQUIRE_RUNTIME_VALIDATORS="$required" \
		"$DOTFILES_DIR/scripts/stow-lint.sh" "$HOST_CONFIG" "$CAPABILITIES_JSON"
}

install_packages() {
	local -a native_packages aur_packages missing_native=() missing_aur=()
	mapfile -t native_packages < <(collect_packages native)
	mapfile -t aur_packages < <(collect_packages aur)

	local package
	for package in "${native_packages[@]}"; do
		pacman -Q "$package" >/dev/null 2>&1 || missing_native+=("$package")
	done
	for package in "${aur_packages[@]}"; do
		pacman -Q "$package" >/dev/null 2>&1 || missing_aur+=("$package")
	done
	if ((${#missing_native[@]} || ${#missing_aur[@]})); then
		# Arch no admite actualizaciones parciales. Shelly sincroniza y actualiza
		# todo el sistema antes de que un paquete nuevo, incluidas dependencias de
		# AUR, pueda entrar en la transacción.
		if command -v pkexec >/dev/null 2>&1 &&
			[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
			if ((${#missing_native[@]})); then
				info "Polkit actualizará CachyOS por completo e instalará los paquetes nativos que falten."
				pkexec /usr/bin/shelly install standard --upgrade --no-confirm "${missing_native[@]}"
			else
				info "Polkit actualizará CachyOS por completo antes de compilar paquetes AUR."
				pkexec /usr/bin/shelly upgrade standard --no-confirm
			fi
		else
			warn "Polkit gráfico no está disponible; Shelly solicitará sudo para la actualización completa."
			if ((${#missing_native[@]})); then
				shelly install standard --upgrade "${missing_native[@]}"
			else
				shelly upgrade standard
			fi
		fi
	else
		info "Todos los paquetes seleccionados ya están instalados; este apply no actualiza el sistema."
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
