#!/usr/bin/env bash
set -euo pipefail

mode=${1:---check}
case "$mode" in
	--check | --apply) ;;
	*)
		printf 'Uso: %s [--check|--apply]\n' "$0" >&2
		exit 2
		;;
esac

legacy_dir="$HOME/.agents/skills/linear"
canonical_source="$(realpath -m -- "$HOME/.dotfiles/codex/.agents/skills/linear")"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups"
expected_entries=$'LICENSE.txt\nSKILL.md\nSOURCE.md\nagents\nagents/openai.yaml'
managed_links=(LICENSE.txt SKILL.md SOURCE.md agents/openai.yaml)

if [[ ! -e "$legacy_dir" && ! -L "$legacy_dir" ]]; then
	printf 'OK: no existe la ruta heredada %s\n' "$legacy_dir"
	exit 0
fi

for parent in "$HOME/.agents" "$HOME/.agents/skills"; do
	if [[ -L "$parent" ]]; then
		printf 'ERROR: se conserva %s porque su padre es un enlace simbólico: %s\n' \
			"$legacy_dir" "$parent" >&2
		exit 1
	fi
done

if [[ -L "$legacy_dir" || ! -d "$legacy_dir" ]]; then
	printf 'ERROR: se conserva una ruta linear ajena o inesperada: %s\n' "$legacy_dir" >&2
	exit 1
fi

actual_entries="$(find "$legacy_dir" -mindepth 1 -printf '%P\n' | LC_ALL=C sort)"
if [[ "$actual_entries" != "$expected_entries" ]]; then
	printf 'ERROR: se conserva %s porque no contiene solo los enlaces heredados esperados.\n' \
		"$legacy_dir" >&2
	exit 1
fi

for relative in "${managed_links[@]}"; do
	link="$legacy_dir/$relative"
	if [[ ! -L "$link" ]]; then
		printf 'ERROR: se conserva %s porque %s no es un enlace simbólico.\n' \
			"$legacy_dir" "$relative" >&2
		exit 1
	fi
	resolved="$(realpath -m -- "$(dirname "$link")/$(readlink -- "$link")")"
	if [[ "$resolved" != "$canonical_source/$relative" ]]; then
		printf 'ERROR: se conserva %s porque %s no apunta a la fuente canónica retirada.\n' \
			"$legacy_dir" "$relative" >&2
		exit 1
	fi
done

if [[ "$mode" == --check ]]; then
	printf 'MIGRATE: %s se respaldará y retirará al aplicar codex.\n' "$legacy_dir"
	exit 0
fi

mkdir -p "$state_root"
backup_dir="$(mktemp -d -- "$state_root/codex-linear-workflow.XXXXXX")"
mv -- "$legacy_dir" "$backup_dir/linear"
printf 'MIGRATED: enlaces heredados retirados; copia reversible: %s\n' \
	"$backup_dir/linear"
