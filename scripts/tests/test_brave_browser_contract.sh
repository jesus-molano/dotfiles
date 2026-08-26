#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly assets_dir="$repo_root/hypr-common/.local/share/brave-project-atlas-theme"

grep -Fqx 'base,core,brave-bin,native' "$repo_root/packages.csv"
if grep -Eq '(^|,)(qutebrowser|python-adblock)(,|$)' "$repo_root/packages.csv"; then
	exit 1
fi
grep -Fq 'BROWSER      = "brave"' "$repo_root/hypr-common/.config/hypr/config/variables.lua"
grep -Fq '"Open Brave"' "$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
grep -Fq "readonly opener=\"\${DEV_PORTS_OPENER:-brave}\"" "$repo_root/hypr-common/.local/bin/dev-ports"
grep -Fq "exec brave \"\$url\"" "$repo_root/hypr-common/.local/bin/project-preview"

for mime in \
	text/html \
	x-scheme-handler/http \
	x-scheme-handler/https \
	x-scheme-handler/about \
	x-scheme-handler/unknown; do
	grep -Fqx "$mime=brave-browser.desktop" "$repo_root/mimeapps/.config/mimeapps.list"
done

[[ ! -e "$assets_dir/manifest.json" ]]

vimium_css="$assets_dir/vimium-c.css"
grep -Fq '/* #ui */' "$vimium_css"
grep -Fq '/* #omni */' "$vimium_css"
grep -Fq '/* #find */' "$vimium_css"
grep -Fq '#ffc857' "$vimium_css"
grep -Fq '#ff9f1c' "$vimium_css"
grep -Fq '#0a0907' "$vimium_css"
grep -Fqx 'a,' "$vimium_css"
grep -Fqx 'match,' "$vimium_css"
grep -Fqx '.label,' "$vimium_css"
grep -Fqx '.time,' "$vimium_css"
grep -Fq 'brave-project-atlas-theme' "$repo_root/docs/DESKTOP-WORKFLOW.md"
grep -Fq 'BrowserThemeColor' "$repo_root/hypr-common/.local/bin/appearance-switch"
grep -Fq 'sin reiniciar el' "$repo_root/docs/DESKTOP-WORKFLOW.md"
grep -Fq 'setup-brave-project-atlas-policy' "$repo_root/docs/DESKTOP-WORKFLOW.md"
grep -Fq 'project-atlas-brave-policy-sync' \
	"$repo_root/hypr-common/.local/bin/setup-brave-project-atlas-policy"
grep -Fq 'keys == ["BrowserThemeColor"]' \
	"$repo_root/hypr-common/.local/libexec/project-atlas-brave-policy-sync"

printf '%s\n' 'PASS: Brave usa la política dinámica y conserva el CSS de Vimium C'
