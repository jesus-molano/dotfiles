#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
profile=${1:-}
if [[ -z "$profile" ]]; then
	active_monitors="$(readlink -f "$HOME/.config/hypr/config/monitors.lua" 2>/dev/null || true)"
	case "$active_monitors" in
	"$repo_root/hypr-desktop"/*) profile=desktop ;;
	"$repo_root/hypr-laptop"/*) profile=workstation ;;
	*) profile=workstation ;;
	esac
fi
[[ "$profile" == workstation || "$profile" == desktop ]] || {
	printf 'Perfil no válido: %s\n' "$profile" >&2
	exit 2
}
readonly profile
failures=0
warnings=0

ok() { printf '✓ %s\n' "$1"; }
info() { printf '· %s\n' "$1"; }
fail() {
	printf '✗ %s\n' "$1" >&2
	failures=$((failures + 1))
}
warn() {
	printf '! %s\n' "$1"
	warnings=$((warnings + 1))
}

check() {
	local label=$1
	shift
	local output
	if output="$("$@" 2>&1)"; then
		ok "$label"
	else
		printf '%s\n' "$output" >&2
		fail "$label"
	fi
}

check_empty() {
	local label=$1
	shift
	local output
	if ! output="$("$@" 2>&1)"; then
		printf '%s\n' "$output" >&2
		fail "$label"
	elif [[ -n "$output" ]]; then
		printf '%s\n' "$output" >&2
		fail "$label"
	else
		ok "$label"
	fi
}

check_gaming_packages() {
	local -a required_packages=() missing_packages=()
	local package

	mapfile -t required_packages < <(
		awk -F, '$1 == "gaming" { print $2 }' "$repo_root/packages.csv" | sort -u
	)
	if ((${#required_packages[@]} == 0)); then
		fail "El manifiesto no declara paquetes gaming"
		return
	fi

	for package in "${required_packages[@]}"; do
		pacman -Qq "$package" >/dev/null 2>&1 || missing_packages+=("$package")
	done
	if ((${#missing_packages[@]})); then
		fail "Paquetes gaming ausentes: ${missing_packages[*]}"
	else
		ok "Paquetes gaming instalados (${#required_packages[@]})"
	fi
}

check_nvidia_stack() {
	local gpu_info

	if command -v chwd >/dev/null 2>&1; then
		check "Perfil nvidia-open-dkms reconocido por CHWD" chwd --check nvidia-open-dkms
	else
		fail "CHWD no está disponible"
	fi

	if gpu_info="$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>&1)"; then
		ok "NVIDIA operativo: $gpu_info"
	else
		printf '%s\n' "$gpu_info" >&2
		fail "nvidia-smi no puede consultar la GPU"
	fi

	check "Runtime NVIDIA/Vulkan de 32 bits" pacman -Qq \
		lib32-nvidia-utils lib32-vulkan-icd-loader
}

check_gaming_scheduler() {
	local ananicy_active=0
	local gamemode_present=0

	if systemctl is-active --quiet ananicy-cpp.service; then
		ananicy_active=1
		ok "ananicy-cpp activo"
	else
		fail "ananicy-cpp no está activo"
	fi

	if pacman -Qq gamemode >/dev/null 2>&1 || command -v gamemoderun >/dev/null 2>&1 ||
		pgrep -x gamemoded >/dev/null 2>&1; then
		gamemode_present=1
	fi
	if ((ananicy_active && gamemode_present)); then
		warn "GameMode coexiste con ananicy-cpp; no los envuelvas juntos"
	else
		ok "Sin coexistencia activa de GameMode y ananicy-cpp"
	fi

	if command -v game-performance >/dev/null 2>&1; then
		ok "game-performance disponible"
	else
		fail "game-performance no está disponible"
	fi
}

check_gaming_monitors() {
	local monitor_json monitor_summary

	if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
		info "Monitor gaming no comprobado: Hyprland no está accesible"
		return
	fi
	if ! monitor_json="$(hyprctl -j monitors 2>/dev/null)"; then
		fail "No se pudieron consultar los monitores activos"
		return
	fi
	if jq -e '
		type == "array" and
		(. as $monitors |
			["HDMI-A-1", "HDMI-A-2"] |
			all(.[]; . as $expected |
				any($monitors[];
					.name == $expected and
					.refreshRate >= 74.8 and .refreshRate <= 75.1 and
					.vrr == false)))
	' >/dev/null 2>&1 <<<"$monitor_json"; then
		ok "HDMI-A-1 y HDMI-A-2 a 74.97/75 Hz con VRR desactivado"
	else
		monitor_summary="$(
			jq -r '.[] | "\(.name): \(.refreshRate) Hz, VRR=\(.vrr)"' \
				<<<"$monitor_json" 2>/dev/null || true
		)"
		[[ -z "$monitor_summary" ]] || printf '%s\n' "$monitor_summary" >&2
		fail "HDMI-A-1/2 no coinciden con 74.97/75 Hz y VRR desactivado"
	fi
}

check_steam_filesystems() {
	local -a steam_paths=(
		"$HOME/.local/share/Steam"
		"$HOME/.steam/steam"
		"$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
	)
	local -a library_files=()
	local steam_path library_file resolved fstype
	local found=0
	local -A seen_paths=()

	for steam_path in "${steam_paths[@]}"; do
		[[ -f "$steam_path/steamapps/libraryfolders.vdf" ]] &&
			library_files+=("$steam_path/steamapps/libraryfolders.vdf")
	done
	for library_file in "${library_files[@]}"; do
		while IFS= read -r steam_path; do
			[[ -z "$steam_path" ]] || steam_paths+=("$steam_path")
		done < <(
			sed -nE 's/^[[:space:]]*"path"[[:space:]]*"([^"]+)".*/\1/p' \
				"$library_file"
		)
	done

	for steam_path in "${steam_paths[@]}"; do
		[[ -d "$steam_path" ]] || continue
		resolved="$(readlink -f -- "$steam_path" 2>/dev/null || true)"
		[[ -n "$resolved" ]] || continue
		[[ -z "${seen_paths[$resolved]+x}" ]] || continue
		seen_paths["$resolved"]=1
		found=$((found + 1))
		fstype="$(findmnt -n -o FSTYPE -T "$resolved" 2>/dev/null || true)"
		case "$fstype" in
		btrfs)
			ok "Biblioteca Steam en Btrfs: $resolved"
			;;
		ntfs | ntfs3 | fuseblk)
			fail "Biblioteca Steam en NTFS no admitida: $resolved"
			;;
		*)
			warn "Biblioteca Steam fuera de Btrfs ($fstype): $resolved"
			;;
		esac
	done
	((found > 0)) || info "Steam aún no tiene una biblioteca local que comprobar"
}

check_dualsense() {
	if modinfo hid_playstation >/dev/null 2>&1; then
		ok "Driver hid-playstation disponible"
	else
		fail "Driver hid-playstation no disponible"
	fi

	if systemctl is-active --quiet bluetooth.service; then
		ok "Bluetooth activo para DualSense"
	else
		warn "Bluetooth no está activo; DualSense queda disponible por USB"
	fi

	if grep -Eiq 'Name=.*(DualSense|Sony Interactive Entertainment.*Wireless Controller)' \
		/proc/bus/input/devices 2>/dev/null ||
		{ command -v lsusb >/dev/null 2>&1 && lsusb | grep -Eiq '054c:(0ce6|0df2)'; }; then
		ok "DualSense conectado"
	else
		info "DualSense no conectado (comprobación opcional)"
	fi
}

check_nvidia_cache() {
	local cache_config="$HOME/.config/environment.d/90-nvidia-game-cache.conf"
	local manager_cache=''

	if [[ ! -f "$cache_config" ]]; then
		fail "Falta la configuración de caché NVIDIA: $cache_config"
	elif ! grep -qx '__GL_SHADER_DISK_CACHE=1' "$cache_config" ||
		! grep -qx '__GL_SHADER_DISK_CACHE_SIZE=12000000000' "$cache_config"; then
		fail "La configuración de caché NVIDIA no coincide con 12 GB"
	else
		ok "Caché de shaders NVIDIA configurada a 12 GB"
	fi

	if [[ "${__GL_SHADER_DISK_CACHE:-}" == 1 &&
		"${__GL_SHADER_DISK_CACHE_SIZE:-}" == 12000000000 ]]; then
		ok "Variables de caché NVIDIA cargadas en la sesión"
	elif manager_cache="$(
		systemctl --user show-environment 2>/dev/null |
			grep -E '^__GL_SHADER_DISK_CACHE(=1|_SIZE=12000000000)$' || true
	)" && [[ "$manager_cache" == *'__GL_SHADER_DISK_CACHE=1'* &&
		"$manager_cache" == *'__GL_SHADER_DISK_CACHE_SIZE=12000000000'* ]]; then
		ok "Variables de caché NVIDIA cargadas para nuevas aplicaciones UWSM"
	else
		warn "La sesión aún no cargó las variables de caché NVIDIA; vuelve a entrar"
	fi
}

check_ignored_nvidia_parameter() {
	local kernel_log

	if ! command -v journalctl >/dev/null 2>&1; then
		info "Journal no disponible para revisar parámetros NVIDIA"
		return
	fi
	if ! kernel_log="$(journalctl -b -k --no-pager 2>/dev/null)"; then
		info "Journal del kernel no accesible; parámetro NVIDIA no comprobado"
		return
	fi
	if grep -Fq "nvidia: unknown parameter 'NVreg_UsePageAttributeTable' ignored" \
		<<<"$kernel_log"; then
		warn "NVIDIA ignoró NVreg_UsePageAttributeTable en este arranque (no fatal)"
	else
		ok "Sin parámetros NVIDIA ignorados conocidos en este arranque"
	fi
}

check_gaming() {
	printf '\nGaming (solo desktop)\n'
	check_gaming_packages
	check_nvidia_stack
	check_gaming_scheduler
	check_gaming_monitors
	check_steam_filesystems
	check_dualsense
	check_nvidia_cache
	check_ignored_nvidia_parameter
}

printf 'Configuración\n'
check "Hyprland workstation" env HYPR_PROFILE_DIR="$repo_root/hypr-laptop/.config/hypr" \
	Hyprland --verify-config -c "$repo_root/hypr-common/.config/hypr/hyprland.lua"
check "Hyprland desktop" env HYPR_PROFILE_DIR="$repo_root/hypr-desktop/.config/hypr" \
	Hyprland --verify-config -c "$repo_root/hypr-common/.config/hypr/hyprland.lua"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
	check_empty "Hyprland sin errores activos" hyprctl configerrors
else
	warn "Hyprland no está disponible en esta sesión"
fi
check "Noctalia" noctalia config validate "$repo_root/noctalia/.config/noctalia/config.toml"
check "Kanata" kanata --check -c "$repo_root/kanata/.config/kanata/config.kbd"
check "Base CachyOS" "$repo_root/hypr-common/.local/bin/hypr-check-cachyos-base"

printf '\nDespliegue\n'
check "Stow $profile" just --justfile "$repo_root/justfile" check "$profile"
check "Whitespace Git" git -C "$repo_root" diff --check

printf '\nSistema\n'
system_failed="$(systemctl --failed --no-legend --plain 2>/dev/null || true)"
if [[ -z "$system_failed" ]]; then
	ok "Sin unidades del sistema fallidas"
else
	fail "Hay unidades del sistema fallidas"
	printf '%s\n' "$system_failed"
fi
user_failed="$(systemctl --user --failed --no-legend --plain 2>/dev/null || true)"
if [[ -z "$user_failed" ]]; then
	ok "Sin unidades de usuario fallidas"
else
	fail "Hay unidades de usuario fallidas"
	printf '%s\n' "$user_failed"
fi

if systemctl is-enabled --quiet btrfs-scrub@-.timer; then
	ok "Scrub Btrfs periódico activo"
else
	warn "Scrub Btrfs periódico desactivado"
fi

if journalctl -b --no-pager 2>/dev/null | grep -q 'Timed out waiting for device /dev/tpm'; then
	warn "El arranque esperó por un dispositivo TPM inexistente"
else
	ok "Sin timeout TPM en este arranque"
fi

mapfile -t orphans < <(pacman -Qdtq 2>/dev/null)
if ((${#orphans[@]})); then
	warn "Paquetes huérfanos: ${orphans[*]}"
else
	ok "Sin paquetes huérfanos"
fi

if [[ "$profile" == desktop ]]; then
	check_gaming
fi

printf '\nResultado: %d fallo(s), %d aviso(s)\n' "$failures" "$warnings"
((failures == 0))
