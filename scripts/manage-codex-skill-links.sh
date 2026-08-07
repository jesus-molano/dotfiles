#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly DOTFILES_DIR

mode=${1:---check}
case "$mode" in
	--check | --apply | --check-remove | --remove) ;;
	*)
		printf 'Uso: %s [--check|--apply|--check-remove|--remove]\n' "$0" >&2
		exit 2
		;;
esac

source_input="${CODEX_SKILLS_SOURCE_ROOT:-$DOTFILES_DIR/codex/.agents/skills}"
skills_input="${CODEX_SKILLS_ROOT:-$HOME/.agents/skills}"
home_root="$(realpath -m -s -- "$HOME")"
source_root="$(realpath -- "$source_input")"
skills_root="$(realpath -m -s -- "$skills_input")"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/codex-skills/backups"
readonly home_root source_root skills_root state_root
readonly -a externally_managed=(frontend-task reuse-first visual-direction)

[[ "$skills_root" == "$home_root"/* ]] || {
	printf 'ERROR: el destino de skills debe estar dentro de HOME: %s\n' "$skills_root" >&2
	exit 1
}

probe="$skills_root"
while [[ "$probe" == "$home_root"/* ]]; do
	if [[ -L "$probe" ]]; then
		printf 'ERROR: el destino de skills atraviesa un directorio enlazado: %s\n' \
			"$probe" >&2
		exit 1
	fi
	probe="$(dirname -- "$probe")"
done

is_externally_managed() {
	local requested=$1 external
	for external in "${externally_managed[@]}"; do
		[[ "$requested" != "$external" ]] || return 0
	done
	return 1
}

declare -a managed_skills=()
while IFS= read -r skill; do
	is_externally_managed "$skill" || managed_skills+=("$skill")
done < <(find "$source_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)

((${#managed_skills[@]} > 0)) || {
	printf 'ERROR: no hay skills locales para gestionar en %s\n' "$source_root" >&2
	exit 1
}

if [[ -n "$(find "$source_root" -type l -print -quit)" ]]; then
	printf 'ERROR: la fuente de skills contiene enlaces simbólicos: %s\n' "$source_root" >&2
	exit 1
fi

legacy_stow_tree() {
	local skill=$1
	local source="$source_root/$skill" target="$skills_root/$skill"
	local source_entries target_entries relative resolved
	[[ -d "$target" && ! -L "$target" ]] || return 1
	source_entries="$(find "$source" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)"
	target_entries="$(find "$target" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)"
	[[ "$source_entries" == "$target_entries" ]] || return 1

	while IFS= read -r -d '' relative; do
		[[ -d "$target/$relative" && ! -L "$target/$relative" ]] || return 1
	done < <(find "$source" -mindepth 1 -type d -printf '%P\0')

	while IFS= read -r -d '' relative; do
		[[ -L "$target/$relative" ]] || return 1
		resolved="$(readlink -f -- "$target/$relative" 2>/dev/null || true)"
		[[ "$resolved" == "$source/$relative" ]] || return 1
	done < <(find "$source" -type f -printf '%P\0')
}

classify_target() {
	local skill=$1
	local target="$skills_root/$skill" resolved
	if [[ ! -e "$target" && ! -L "$target" ]]; then
		REPLY=absent
		return 0
	fi
	if [[ -L "$target" ]]; then
		resolved="$(readlink -f -- "$target" 2>/dev/null || true)"
		if [[ "$resolved" == "$source_root/$skill" ]]; then
			REPLY=current
			return 0
		fi
		return 1
	fi
	if legacy_stow_tree "$skill"; then
		REPLY=legacy
		return 0
	fi
	return 1
}

declare -A target_state=()
pending=0
invalid=0
for skill in "${managed_skills[@]}"; do
	if classify_target "$skill"; then
		target_state["$skill"]=$REPLY
		[[ "$REPLY" == current ]] || ((pending += 1))
	else
		printf 'ERROR: se conserva una skill ajena o inesperada: %s/%s\n' \
			"$skills_root" "$skill" >&2
		invalid=1
	fi
done
((invalid == 0)) || exit 1

if [[ "$mode" == --check ]]; then
	if ((pending)); then
		printf 'SYNC: %d skill(s) se convertirán en enlaces de carpeta compatibles con Codex.\n' \
			"$pending"
	else
		printf 'OK: %d skills locales usan enlaces de carpeta compatibles con Codex.\n' \
			"${#managed_skills[@]}"
	fi
	exit 0
fi

if [[ "$mode" == --check-remove ]]; then
	removable=0
	for skill in "${managed_skills[@]}"; do
		[[ "${target_state[$skill]}" == absent ]] || ((removable += 1))
	done
	printf 'REMOVE: se respaldarán y retirarán %d enlaces o árboles gestionados de skills.\n' \
		"$removable"
	exit 0
fi

if [[ "$mode" == --apply && "$pending" == 0 ]]; then
	printf 'OK: %d skills locales ya están sincronizadas.\n' "${#managed_skills[@]}"
	exit 0
fi

if [[ "$mode" == --remove ]]; then
	removable=0
	for skill in "${managed_skills[@]}"; do
		[[ "${target_state[$skill]}" == absent ]] || ((removable += 1))
	done
	if ((removable == 0)); then
		printf 'OK: no hay enlaces de skills locales que retirar.\n'
		exit 0
	fi
fi

mkdir -p -- "$state_root" "$skills_root"
backup_root="$(mktemp -d -- "$state_root/sync-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
chmod 700 "$backup_root"
mkdir -p -- "$backup_root/skills" "$backup_root/failed"
declare -A touched=() previous=()
rollback_active=1

rollback() {
	local trapped_status=$?
	local status=${1:-$trapped_status} skill target backup failed
	((status != 0)) || status=1
	trap - ERR INT TERM
	if ((rollback_active)); then
		printf 'Falló la gestión de skills; restaurando destinos previos.\n' >&2
		for skill in "${managed_skills[@]}"; do
			[[ "${touched[$skill]:-0}" == 1 ]] || continue
			target="$skills_root/$skill"
			backup="$backup_root/skills/$skill"
			failed="$backup_root/failed/$skill"
			if [[ -e "$target" || -L "$target" ]]; then
				mv -- "$target" "$failed"
			fi
			if [[ "${previous[$skill]:-0}" == 1 ]]; then
				mv -- "$backup" "$target"
			fi
		done
		printf 'Backup y restos recuperables: %s\n' "$backup_root" >&2
	fi
	exit "$status"
}
trap rollback ERR INT TERM

for skill in "${managed_skills[@]}"; do
	state=${target_state[$skill]}
	if [[ "$mode" == --apply && "$state" == current ]]; then
		continue
	fi
	if [[ "$mode" == --remove && "$state" == absent ]]; then
		continue
	fi
	target="$skills_root/$skill"
	if [[ -e "$target" || -L "$target" ]]; then
		mv -- "$target" "$backup_root/skills/$skill"
		previous["$skill"]=1
	fi
	touched["$skill"]=1
	if [[ "$mode" == --apply ]]; then
		ln -s -- "$source_root/$skill" "$target"
	fi
done

if [[ "$mode" == --apply ]]; then
	for skill in "${managed_skills[@]}"; do
		classify_target "$skill" && [[ "$REPLY" == current ]]
	done
fi

rollback_active=0
trap - ERR INT TERM
if [[ "$mode" == --apply ]]; then
	printf 'Codex skills sincronizadas con enlaces de carpeta. Backup: %s\n' "$backup_root"
else
	printf 'Codex skills retiradas con copia reversible: %s\n' "$backup_root"
fi
