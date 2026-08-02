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

printf '\nResultado: %d fallo(s), %d aviso(s)\n' "$failures" "$warnings"
((failures == 0))
