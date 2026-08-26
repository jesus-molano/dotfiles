#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

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

printf '%s\n' 'PASS: Brave es el navegador único de los contratos del escritorio'
