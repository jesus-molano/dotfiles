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
for label in 'Sesión Orca + terminal - ' 'Orca - ' 'Ghostty - ' 'Nvim - ' 'Tareas - ' 'Preview - '; do
	[[ "$project_list" == *"$label"* ]] || {
		printf 'FAIL: el launcher no publicó %s\n%s\n' "$label" "$project_list" >&2
		exit 1
	}
done

session_token=$(awk -F '\t' '$2 ~ /^Sesión Orca \+ terminal - / { print $1; exit }' <<<"$project_list")
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

printf '%s\n' 'PASS: /proj publica y ejecuta acciones seguras de Project Cockpit'
