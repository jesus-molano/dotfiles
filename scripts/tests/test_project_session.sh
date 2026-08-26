#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly project_session=${1:-"$repo_root/hypr-common/.local/bin/project-session"}
readonly project_task="$repo_root/hypr-common/.local/bin/project-task"
readonly project_preview="$repo_root/hypr-common/.local/bin/project-preview"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

project="$test_root/example-project"
mkdir -p "$project/.git" "$test_root/bin"
printf '%s\n' 'check:' >"$project/justfile"
printf '%s\n' '[tasks.lint]' 'run = "echo lint"' >"$project/mise.toml"
cat >"$project/package.json" <<'EOF'
{
  "scripts": {
    "dev": "vite",
    "test": "vitest"
  },
  "projectCockpit": {
    "previewUrl": "http://localhost:5173"
  }
}
EOF
touch "$project/pnpm-lock.yaml"

cat >"$test_root/bin/pnpm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'pnpm %s\n' "$*"
EOF
cat >"$test_root/bin/test-shell" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'shell abierta'
EOF
cat >"$test_root/bin/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
awk -F '\t' '$1 == "package" && $2 == "test" { print; exit }'
EOF
cat >"$test_root/bin/orca-ide" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
"repo list --json") printf '%s\n' '{"ok":true,"result":{"repos":[]}}' ;;
"repo add --path "*" --json") exit 1 ;;
*) exit 2 ;;
esac
EOF
cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${TEST_NOTIFICATION_LOG:-}" ]]; then
	printf '%s\n' "$*" >>"$TEST_NOTIFICATION_LOG"
fi
exit 0
EOF
cat >"$test_root/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count=0
[[ ! -f "$TEST_CURL_COUNT" ]] || count=$(<"$TEST_CURL_COUNT")
count=$((count + 1))
printf '%s\n' "$count" >"$TEST_CURL_COUNT"
((count >= 2))
EOF
cat >"$test_root/bin/brave" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$TEST_BROWSER_LOG"
EOF
chmod +x "$test_root/bin/pnpm" "$test_root/bin/test-shell"
chmod +x "$test_root/bin/fzf" "$test_root/bin/orca-ide" "$test_root/bin/noctalia" \
	"$test_root/bin/curl" "$test_root/bin/brave"

assert_contains() {
	local needle=$1 haystack=$2
	[[ "$haystack" == *"$needle"* ]] || {
		printf 'FAIL: falta %q en:\n%s\n' "$needle" "$haystack" >&2
		return 1
	}
}

resume_output=$("$project_session" --dry-run resume "$project")
assert_contains $'DRY-RUN\torca-register' "$resume_output"
assert_contains $'DRY-RUN\torca' "$resume_output"
assert_contains $'DRY-RUN\tterminal' "$resume_output"
[[ "$resume_output" != *$'DRY-RUN\tnvim'* ]] || {
	printf '%s\n' 'FAIL: la sesión principal abrió Nvim pese a que Orca/Codex son el flujo principal.' >&2
	exit 1
}

nvim_output=$("$project_session" --dry-run nvim "$project")
assert_contains $'DRY-RUN\tnvim' "$nvim_output"

task_output=$("$project_session" --dry-run tasks "$project")
assert_contains $'DRY-RUN\ttasks' "$task_output"
assert_contains 'project-task' "$task_output"
assert_contains 'attach' "$task_output"
assert_contains '--create' "$task_output"
assert_contains '--default-shell' "$task_output"
[[ "$task_output" != *'--layout-string'* && "$task_output" != *'--new-session-with-layout'* ]] || {
	printf '%s\n' 'FAIL: la sesión de tareas volvió a depender de un layout dinámico.' >&2
	exit 1
}

preview_output=$("$project_session" --dry-run preview "$project")
assert_contains $'DRY-RUN\tpreview' "$preview_output"
assert_contains 'project-preview' "$preview_output"
assert_contains $'DRY-RUN\tpreview-url' "$preview_output"
assert_contains 'project-preview' "$preview_output"
assert_contains '--open' "$preview_output"

detected=$("$project_task" --detect "$project")
assert_contains just "$detected"
assert_contains mise "$detected"
assert_contains package "$detected"
[[ "$("$project_preview" --script "$project")" == dev ]]
[[ "$("$project_preview" --url "$project")" == http://localhost:5173 ]]
PATH="$test_root/bin:$PATH" TEST_CURL_COUNT="$test_root/curl-count" \
	TEST_BROWSER_LOG="$test_root/browser-log" "$project_preview" --open "$project"
[[ "$(<"$test_root/curl-count")" == 2 ]]
[[ "$(<"$test_root/browser-log")" == http://localhost:5173 ]]

default_task_output=$(cd -- "$project" && SHELL="$test_root/bin/test-shell" "$project_task")
assert_contains 'Proyecto:' "$default_task_output"

selected_task_output=$(
	cd -- "$project"
	PATH="$test_root/bin:$PATH" PROJECT_TASK_FORCE_SELECTOR=1 \
		SHELL="$test_root/bin/test-shell" "$project_task"
)
assert_contains 'Tarea: package · test' "$selected_task_output"
assert_contains 'pnpm run test' "$selected_task_output"

default_preview=$(
	cd -- "$project"
	PATH="$test_root/bin:$PATH" "$project_preview" 2>&1 || true
)
assert_contains 'pnpm run dev' "$default_preview"

notification_log="$test_root/notifications.log"
for invalid_action in resume has-tasks has-preview; do
	set +e
	invalid_output=$(PATH="$test_root/bin:$PATH" TEST_NOTIFICATION_LOG="$notification_log" \
		"$project_session" --dry-run "$invalid_action" "$test_root/not-a-project" 2>&1)
	invalid_status=$?
	set -e
	[[ $invalid_status -ne 0 ]] || {
		printf 'FAIL: project-session aceptó una ruta inválida para %s.\n' "$invalid_action" >&2
		exit 1
	}
	assert_contains 'La ruta no es un repositorio Git disponible.' "$invalid_output"
done
[[ ! -s "$notification_log" ]] || {
	printf 'FAIL: una ruta inválida generó notificaciones de escritorio:\n%s\n' \
		"$(<"$notification_log")" >&2
	exit 1
}

set +e
PATH="$test_root/bin:$PATH" "$project_session" orca "$project" >/dev/null 2>&1
orca_failure_status=$?
set -e
[[ $orca_failure_status -ne 0 ]] || {
	printf '%s\n' 'FAIL: project-session ocultó el fallo de registro en Orca.' >&2
	exit 1
}

printf '%s\n' 'PASS: project-session resuelve acciones, tareas y preview sin ejecutar aplicaciones'
