#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly migrator=${1:-"$repo_root/scripts/migrate-retired-desktop-links.sh"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/home/.local/share/noctalia/plugins/dev-pulse"
mkdir -p "$test_root/home/.local/share/wallpapers/project-atlas"
mkdir -p "$test_root/home/.local/share/wallpapers/project-atlas/atlas"
mkdir -p "$test_root/home/.local/share/wallpapers/noctalia-themes/atlas"
mkdir -p "$test_root/home/.local/bin"
ln -s "$repo_root/noctalia/.local/share/noctalia/plugins/dev-pulse/plugin.toml" \
	"$test_root/home/.local/share/noctalia/plugins/dev-pulse/plugin.toml"
ln -s "$repo_root/noctalia/.local/share/wallpapers/project-atlas/nord-night.png" \
	"$test_root/home/.local/share/wallpapers/project-atlas/nord-night.png"
ln -s "$repo_root/noctalia/.local/share/wallpapers/project-atlas/atlas/default.png" \
	"$test_root/home/.local/share/wallpapers/project-atlas/atlas/default.png"
ln -s /tmp/unrelated "$test_root/home/.local/bin/dev-pulse-status"
ln -s /tmp/user-wallpaper "$test_root/home/.local/share/wallpapers/project-atlas/user.png"
ln -s "$repo_root/noctalia/.local/share/wallpapers/noctalia-themes/atlas/removed.png" \
	"$test_root/home/.local/share/wallpapers/noctalia-themes/atlas/removed.png"
ln -s "$repo_root/noctalia/.local/share/wallpapers/noctalia-themes/atlas/default.png" \
	"$test_root/home/.local/share/wallpapers/noctalia-themes/atlas/default.png"

checked=$(HOME="$test_root/home" "$migrator" --check)
grep -Fq 'plugins/dev-pulse/plugin.toml' <<<"$checked"
grep -Fq 'nord-night.png' <<<"$checked"
grep -Fq 'atlas/default.png' <<<"$checked"
grep -Fq 'noctalia-themes/atlas/removed.png' <<<"$checked"
[[ -L "$test_root/home/.local/share/noctalia/plugins/dev-pulse/plugin.toml" ]]

HOME="$test_root/home" "$migrator" --apply >"$test_root/applied"
[[ ! -L "$test_root/home/.local/share/noctalia/plugins/dev-pulse/plugin.toml" ]]
[[ ! -L "$test_root/home/.local/share/wallpapers/project-atlas/nord-night.png" ]]
[[ ! -L "$test_root/home/.local/share/wallpapers/project-atlas/atlas/default.png" ]]
[[ ! -d "$test_root/home/.local/share/wallpapers/project-atlas/atlas" ]]
[[ -L "$test_root/home/.local/share/wallpapers/project-atlas/user.png" ]]
[[ ! -L "$test_root/home/.local/share/wallpapers/noctalia-themes/atlas/removed.png" ]]
[[ -L "$test_root/home/.local/share/wallpapers/noctalia-themes/atlas/default.png" ]]
[[ -L "$test_root/home/.local/bin/dev-pulse-status" ]]
HOME="$test_root/home" "$migrator" --apply | grep -Fxq 'No hay enlaces retirados del desktop.'

printf '%s\n' 'PASS: la migración retira solo enlaces obsoletos propiedad de estos dotfiles'
