#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
profile=${1:-}
common=(codex fish fonts ghostty git hypr-common kanata mimeapps noctalia nvim qutebrowser shell starship vscode zellij)

case "$profile" in
workstation) packages=("${common[@]}" hypr-laptop) ;;
desktop) packages=("${common[@]}" hypr-desktop gaming backup) ;;
*)
	printf 'Perfil no válido: %s\n' "$profile" >&2
	exit 2
	;;
esac

runtime_root=${XDG_RUNTIME_DIR:-/tmp}
target="$(mktemp -d --tmpdir="$runtime_root" dotfiles-stow-lint.XXXXXX)"
cleanup() {
	[[ "$target" == "$runtime_root"/dotfiles-stow-lint.* ]] || return 1
	rm -rf -- "$target"
}
trap cleanup EXIT

stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' \
	--simulate --verbose=1 --dir "$repo_root" --target "$target" "${packages[@]}"
