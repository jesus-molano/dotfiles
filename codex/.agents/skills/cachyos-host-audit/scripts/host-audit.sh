#!/usr/bin/env bash
set -euo pipefail

profile=${1:-desktop}
[[ "$profile" == desktop || "$profile" == workstation ]] || {
	printf 'Perfil no válido: %s\n' "$profile" >&2
	exit 2
}

for candidate in "${DOTFILES_DIR:-}" "$HOME/.dotfiles"; do
	[[ -n "$candidate" && -x "$candidate/scripts/doctor.sh" ]] || continue
	exec "$candidate/scripts/doctor.sh" "$profile" --live-only
done

printf '%s\n' 'No se encontró scripts/doctor.sh en DOTFILES_DIR ni ~/.dotfiles.' >&2
printf '%s\n' 'Ejecuta las comprobaciones de references/checklist.md manualmente.' >&2
exit 1
