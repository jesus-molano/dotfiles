#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly theme_dir="$repo_root/hypr-common/.local/share/brave-project-atlas-theme"

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

python3 - "$theme_dir/manifest.json" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["manifest_version"] == 3
assert manifest["name"] == "Project Atlas - Obsidian Amber"
colors = manifest["theme"]["colors"]
assert colors["frame"] == [10, 9, 7]
assert colors["toolbar"] == [21, 19, 14]
assert colors["toolbar_text"] == [245, 241, 232]
assert colors["ntp_background"] == [7, 6, 4]
assert colors["ntp_link"] == [255, 200, 87]
PY

vimium_css="$theme_dir/vimium-c.css"
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

printf '%s\n' 'PASS: Brave es el navegador único y su tema Atlas es válido'
