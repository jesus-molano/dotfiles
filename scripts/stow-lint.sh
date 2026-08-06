#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
profile=${1:-}

# shellcheck source=profiles.sh
source "$repo_root/profiles.sh"
if ! profile_is_valid "$profile"; then
	printf 'Perfil no válido: %s\n' "$profile" >&2
	exit 2
fi
mapfile -t packages < <(profile_modules "$profile")

runtime_root=${XDG_RUNTIME_DIR:-/tmp}
target="$(mktemp -d --tmpdir="$runtime_root" dotfiles-stow-lint.XXXXXX)"
cleanup() {
	[[ "$target" == "$runtime_root"/dotfiles-stow-lint.* ]] || return 1
	rm -rf -- "$target"
}
trap cleanup EXIT

stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' \
	--simulate --verbose=1 --dir "$repo_root" --target "$target" "${packages[@]}"
