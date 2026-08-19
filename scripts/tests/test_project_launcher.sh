#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly launcher=${1:-"$repo_root/hypr-common/.local/bin/desktop-launcher"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

project="$test_root/work/demo"
mkdir -p "$project/.git"
printf '%s\n' 'check:' >"$project/justfile"
cat >"$project/package.json" <<'EOF'
{
  "scripts": { "preview": "vite preview" },
  "projectCockpit": { "previewUrl": "http://127.0.0.1:4173" }
}
EOF

project_list=$(HOME="$test_root" "$launcher" list projects)
[[ $(wc -l <<<"$project_list") -eq 1 && "$project_list" == *$'\tdemo — ~/work/demo' ]] || {
	printf 'FAIL: /proj debe publicar una fila con nombre y ruta por repositorio:\n%s\n' "$project_list" >&2
	exit 1
}

session_token=$(awk -F '\t' 'NR == 1 { print $1 }' <<<"$project_list")
[[ -n "$session_token" ]] || {
	printf '%s\n' 'FAIL: no se encontró el token de sesión.' >&2
	exit 1
}

run_output=$(HOME="$test_root" PROJECT_SESSION_DRY_RUN=1 "$launcher" run projects "$session_token")
[[ "$run_output" == *$'DRY-RUN\torca-register'* && "$run_output" == *$'DRY-RUN\tterminal'* && \
	"$run_output" != *$'DRY-RUN\tnvim'* ]] || {
	printf 'FAIL: la sesión no delegó en project-session:\n%s\n' "$run_output" >&2
	exit 1
}

actions_list=$(HOME="$test_root" "$launcher" list project-actions)
for label in 'Sesión Orca + terminal - ' 'Orca - ' 'Ghostty - ' 'Nvim - ' 'Tareas - ' 'Preview - '; do
	[[ "$actions_list" == *"$label"* ]] || {
		printf 'FAIL: /proj-actions no publicó %s\n%s\n' "$label" "$actions_list" >&2
		exit 1
	}
done

nvim_token=$(awk -F '\t' '$2 ~ /^Nvim - / { print $1; exit }' <<<"$actions_list")
[[ -n "$nvim_token" ]] || {
	printf '%s\n' 'FAIL: no se encontró el token Nvim.' >&2
	exit 1
}
if HOME="$test_root" PROJECT_SESSION_DRY_RUN=1 "$launcher" run projects "$nvim_token" >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: /proj aceptó una acción avanzada.' >&2
	exit 1
fi

printf '%s\n' 'PASS: /proj abre sesiones y /proj-actions publica acciones seguras'
