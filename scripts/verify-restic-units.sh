#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
units=(
	"$repo_root"/backup/.config/systemd/user/*.service
	"$repo_root"/backup/.config/systemd/user/*.timer
)

output=''
if output="$(systemd-analyze --user verify "${units[@]}" 2>&1)"; then
	exit 0
fi

# En una rama todavía no desplegada systemd resuelve %h contra el HOME real.
# Ignora únicamente la ausencia esperada de nuestros dos ejecutables; cualquier
# otro diagnóstico de sintaxis o dependencia sigue haciendo fallar la prueba.
unexpected="$(grep -Ev \
	'^restic-(backup|maintenance)\.service: Command .*/\.local/bin/desktop-backup(-maintenance)? is not executable: No such file or directory$' \
	<<<"$output" || true)"
if [[ -z "$unexpected" ]]; then
	exit 0
fi

printf '%s\n' "$unexpected" >&2
exit 1
