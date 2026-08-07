#!/usr/bin/env bash
set -euo pipefail

mode=check
[[ ${1:-} != --apply ]] || mode=apply
rules_file="${CODEX_HOME:-$HOME/.codex}/rules/default.rules"

[[ -e "$rules_file" ]] || {
	printf '✓ No existe el fichero opcional: %s\n' "$rules_file"
	exit 0
}
[[ -f "$rules_file" && ! -L "$rules_file" ]] || {
	printf 'Destino no admitido (debe ser fichero regular): %s\n' "$rules_file" >&2
	exit 1
}

runtime_root=${XDG_RUNTIME_DIR:-}
if [[ -z "$runtime_root" || ! -d "$runtime_root" || ! -w "$runtime_root" ]]; then
	runtime_root=${TMPDIR:-/tmp}
fi
if [[ ! -d "$runtime_root" || ! -w "$runtime_root" ]]; then
	runtime_root=/tmp
fi
filtered="$(mktemp --tmpdir="$runtime_root" codex-rules.XXXXXX)"
trap 'rm -f -- "$filtered"' EXIT

awk '
!/^prefix_rule\(pattern=\["curl", "-fsSL", "https:\/\/(raw.githubusercontent.com\/basecamp\/omarchy\/v3.8.4\/bin\/omarchy-install-gaming-lutris|codeload.github.com\/basecamp\/omarchy\/tar.gz\/refs\/(tags\/v3.8.4|heads\/quattro))"/ &&
!/^prefix_rule\(pattern=\["nvidia-smi", "--query-gpu=name,driver_version,vbios_version,pstate,power.limit,memory.total,temperature.gpu", "--format=csv,noheader"\], decision="allow"\)$/
' "$rules_file" >"$filtered"

if cmp -s -- "$rules_file" "$filtered"; then
	printf '✓ Sin reglas temporales obsoletas: %s\n' "$rules_file"
	exit 0
fi
if [[ "$mode" == check ]]; then
	printf '! Hay reglas temporales obsoletas en: %s\n' "$rules_file"
	exit 1
fi

printf 'Destino exacto: %s\n' "$rules_file"
printf '%s\n' 'Solo se retirarán las reglas exactas de la auditoría Omarchy/NVIDIA.'
printf 'Escribe APLICAR: '
read -r confirmation
[[ "$confirmation" == APLICAR ]] || {
	printf '%s\n' 'Cancelado sin cambios.'
	exit 1
}

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/codex-rules"
backup_root="$state_root/$(date +%Y%m%d-%H%M%S)"
mkdir -p -- "$backup_root"
cp -a -- "$rules_file" "$backup_root/default.rules"
install -m "$(stat -c '%a' "$rules_file")" "$filtered" "$rules_file"
printf '✓ Reglas limpiadas. Backup: %s\n' "$backup_root"
