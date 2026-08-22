#!/usr/bin/env bash
# Copia un módulo de system-etc de forma transaccional. La ejecución normal
# escribe exclusivamente bajo /etc mediante pkexec; las pruebas pueden apuntar
# DOTFILES_SYSTEM_ETC_TARGET_ROOT a un árbol temporal y sustituir pkexec.
set -Eeuo pipefail

usage() {
	printf 'Uso: %s --check|--apply <módulo>\n' "${0##*/}" >&2
	exit 2
}

[[ $# -eq 2 ]] || usage
action=$1
module=$2
[[ "$action" == --check || "$action" == --apply ]] || usage

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source_root="${DOTFILES_SYSTEM_ETC_SOURCE_ROOT:-$repo_root/system-etc}/$module"
target_root=${DOTFILES_SYSTEM_ETC_TARGET_ROOT:-/etc}
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
pkexec_cmd=${DOTFILES_SYSTEM_ETC_PKEXEC:-pkexec}

case "$module" in
	sddm|udev|snapper|systemd) ;;
	*) printf 'Módulo de sistema no permitido: %s\n' "$module" >&2; exit 2 ;;
esac
[[ -d "$source_root" ]] || { printf 'No existe el módulo: %s\n' "$source_root" >&2; exit 2; }
[[ "$target_root" == /* ]] || { printf 'El destino debe ser absoluto: %s\n' "$target_root" >&2; exit 2; }

declare -a sources=() targets=()
render_root=
systemd_uuid=
systemd_uid=
systemd_gid=

cleanup() {
	if [[ -n "$render_root" ]]; then
		rm -rf -- "$render_root"
	fi
}
trap cleanup EXIT

load_systemd_host_config() {
	local config=${DOTFILES_SYSTEMD_MNT_BACKUPS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/systemd-mnt-backups.conf}
	local line key value
	[[ -r "$config" && ! -L "$config" ]] || {
		printf 'Falta la configuración local de systemd: %s\n' "$config" >&2
		printf '%s\n' 'Define MNT_BACKUPS_UUID, MNT_BACKUPS_UID y MNT_BACKUPS_GID para este host.' >&2
		exit 2
	}
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" == \#* ]] && continue
		[[ "$line" == *=* ]] || { printf 'Configuración systemd inválida: %s\n' "$config" >&2; exit 2; }
		key=${line%%=*}
		value=${line#*=}
		case "$key" in
			MNT_BACKUPS_UUID) systemd_uuid=$value ;;
			MNT_BACKUPS_UID) systemd_uid=$value ;;
			MNT_BACKUPS_GID) systemd_gid=$value ;;
			*) printf 'Clave systemd no permitida: %s\n' "$key" >&2; exit 2 ;;
		esac
	done <"$config"
	[[ "$systemd_uuid" =~ ^[A-Za-z0-9-]+$ && "$systemd_uid" =~ ^[0-9]+$ && "$systemd_gid" =~ ^[0-9]+$ ]] || {
		printf 'Configuración systemd incompleta o insegura: %s\n' "$config" >&2
		exit 2
	}
	render_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-systemd.XXXXXX")
}

target_for() {
	local relative=$1
	if [[ "$module" == sddm && "$relative" == conf.d/* ]]; then
		printf '%s/sddm.conf.d/%s\n' "$target_root" "${relative#conf.d/}"
	else
		printf '%s/%s/%s\n' "$target_root" "$module" "$relative"
	fi
}

if [[ "$module" == systemd ]]; then
	load_systemd_host_config
fi

while IFS= read -r -d '' source; do
	relative=${source#"$source_root/"}
	if [[ "$module" == systemd && "$relative" == *.template ]]; then
		relative=${relative%.template}
		rendered_source="$render_root/$relative"
		mkdir -p -- "$(dirname -- "$rendered_source")"
		sed \
			-e "s|@MNT_BACKUPS_UUID@|$systemd_uuid|g" \
			-e "s|@MNT_BACKUPS_UID@|$systemd_uid|g" \
			-e "s|@MNT_BACKUPS_GID@|$systemd_gid|g" \
			-- "$source" >"$rendered_source"
		source=$rendered_source
	fi
	sources+=("$source")
	targets+=("$(target_for "$relative")")
done < <(find "$source_root" -type f -print0 | sort -z)

((${#sources[@]} > 0)) || { printf 'El módulo no contiene archivos: %s\n' "$source_root" >&2; exit 2; }

for index in "${!sources[@]}"; do
	source=${sources[$index]}
	target=${targets[$index]}
	[[ ! -d "$target" ]] || { printf 'El destino es un directorio: %s\n' "$target" >&2; exit 2; }
	if [[ -e "$target" ]] && cmp -s "$source" "$target"; then
		printf '= %s\n' "$target"
	elif [[ -e "$target" || -L "$target" ]]; then
		printf '~ %s\n' "$target"
		[[ "$action" == --check ]] && diff -u --label "$target (actual)" --label "$source (propuesto)" "$target" "$source" || true
	else
		printf '+ %s\n' "$target"
	fi
done

[[ "$action" == --apply ]] || exit 0

backup_root="$state_root/system-backups/$(date +%Y%m%d-%H%M%S)"
journal="$backup_root/journal.tsv"
mkdir -p -- "$backup_root/preimages"
: >"$journal"
applied=0
rollback_started=0

rollback() {
	local status=${1:-$?} line kind target backup rollback_failed=0
	local rollback_failures="$backup_root/rollback-incomplete.tsv"
	# ERR, INT y TERM pueden llegar muy cerca. Desarma los traps antes de tocar
	# los destinos para que el mismo journal nunca se ejecute dos veces.
	if ((rollback_started)); then
		exit "$status"
	fi
	rollback_started=1
	trap - ERR INT TERM
	((applied)) || exit "$status"
	set +e
	printf '%s\n' 'Fallo durante apply-system; se revierte el módulo ya copiado.' >&2
	mapfile -t journal_lines <"$journal"
	for ((index=${#journal_lines[@]} - 1; index >= 0; index--)); do
		IFS=$'\t' read -r kind target backup <<<"${journal_lines[$index]}"
		case "$kind" in
			absent)
				if ! "$pkexec_cmd" /usr/bin/rm -f -- "$target"; then
					printf 'absent\t%s\n' "$target" >>"$rollback_failures"
					rollback_failed=1
				fi
				;;
			existing)
				if ! "$pkexec_cmd" /usr/bin/cp --archive -- "$backup" "$target"; then
					printf 'existing\t%s\n' "$target" >>"$rollback_failures"
					rollback_failed=1
				fi
				;;
		esac
	done
	if ((rollback_failed)); then
		printf 'Rollback incompleto; revisa los destinos registrados en %s\n' "$rollback_failures" >&2
	fi
	exit "$status"
}
trap 'rollback "$?"' ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM

for index in "${!sources[@]}"; do
	source=${sources[$index]}
	target=${targets[$index]}
	if [[ -e "$target" ]] && cmp -s "$source" "$target"; then
		continue
	fi
	if [[ -e "$target" || -L "$target" ]]; then
		backup="$backup_root/preimages$target"
		"$pkexec_cmd" /usr/bin/cp --archive --parents -- "$target" "$backup_root/preimages"
		printf 'existing\t%s\t%s\n' "$target" "$backup" >>"$journal"
	else
		printf 'absent\t%s\t\n' "$target" >>"$journal"
	fi
	mode=$(stat -c '%a' "$source")
	# Desde este punto el destino puede haberse creado o reemplazado incluso si
	# install informa un fallo. El journal ya contiene su preimagen.
	applied=1
	"$pkexec_cmd" /usr/bin/install -D -m "$mode" -- "$source" "$target"
	printf '✓ %s\n' "$target"
done

trap - ERR INT TERM
printf '%s\n' "$backup_root" >"$state_root/last-system-backup"
printf 'Backup: %s\n' "$backup_root"
