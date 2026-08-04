#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
mode=check
[[ ${1:-} != --apply ]] || mode=apply
node_version=26.5.1

command -v mise >/dev/null 2>&1 || {
	printf '%s\n' 'Falta mise; instala primero el perfil desktop.' >&2
	exit 1
}

if [[ "$mode" == apply ]]; then
	mise install "node@$node_version"
elif ! mise where "node@$node_version" >/dev/null 2>&1; then
	printf '%s\n' "! Node $node_version aún no está instalado en mise."
	printf '%s\n' '  Se instalará como parte de just toolchain-migrate.'
	exit 1
fi
node_root="$(mise where "node@$node_version")"
node_path="$node_root/bin/node"
[[ -x "$node_path" && "$node_path" != *'/fnm/'* && "$node_path" != *'/fnm_multishells/'* ]] || {
	printf 'mise no resolvió un Node estable: %s\n' "$node_path" >&2
	exit 1
}
[[ "$("$node_path" --version)" == "v$node_version" ]] || {
	printf 'Versión Node inesperada en mise: %s\n' "$("$node_path" --version)" >&2
	exit 1
}

if ! pacman -Qq fnm >/dev/null 2>&1; then
	printf '✓ mise usa %s y fnm ya no está instalado.\n' "$node_path"
	# Una sesión iniciada con fnm conserva sus directorios en PATH incluso tras
	# retirar el paquete. Fuerza delante el Node estable que acabamos de validar.
	exec env PATH="$node_root/bin:$PATH" \
		"$repo_root/scripts/sync-project-atlas.sh" --check
fi

if [[ "$mode" == check ]]; then
	printf '✓ mise está preparado: %s\n' "$node_path"
	printf '%s\n' '! Migración pendiente: fnm sigue instalado y Atlas aún depende de él.'
	exit 1
fi

printf '%s\n' 'Paquete exacto que se retirará: fnm.'
printf '%s\n' "Node sustituto validado: $node_path"
printf '%s\n' 'Después se reregistrará únicamente [mcp_servers.component-atlas] con backup.'
printf 'Escribe MIGRAR: '
read -r confirmation
[[ "$confirmation" == MIGRAR ]] || {
	printf '%s\n' 'Cancelado sin cambios.'
	exit 1
}

fnm_removed=0
rollback() {
	status=$?
	trap - ERR INT TERM
	if ((fnm_removed)); then
		printf '%s\n' 'Falló la migración después de retirar fnm; se intentará reinstalarlo.' >&2
		pkexec /usr/bin/shelly install standard --no-confirm fnm || true
	fi
	exit "$status"
}
trap rollback ERR INT TERM

pkexec /usr/bin/shelly remove standard --no-confirm fnm
fnm_removed=1

env PATH="$node_root/bin:$PATH" \
	"$repo_root/scripts/sync-project-atlas.sh" --apply

fnm_removed=0
trap - ERR INT TERM
printf '✓ Migración completa: Node %s mediante mise y Atlas revalidado.\n' "$node_version"
