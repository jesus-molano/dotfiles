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

workspace="$test_root/orca/workspaces/dotfiles/auto-hyprland-upstream-radar-run-1-20260805T1000"
mkdir -p "$workspace/.git"

project_list=$(HOME="$test_root" "$launcher" list projects)
grep -Fxq $'demo\tOpen ChatGPT with terminal — ~/work/demo' <<<"$project_list" || {
	printf 'FAIL: /proj debe publicar una fila con nombre y ruta por repositorio:\n%s\n' "$project_list" >&2
	exit 1
}
grep -Fxq $'Hyprland upstream radar\tOpen ChatGPT with terminal — Orca workspace for dotfiles' \
	<<<"$project_list" || {
	printf 'FAIL: /proj no convirtió el nombre técnico del workspace:\n%s\n' "$project_list" >&2
	exit 1
}
[[ "$project_list" != *'auto-hyprland-upstream-radar-run-1-20260805T1000'* ]]

demo_selection=$(grep '^demo'$'\t' <<<"$project_list")
run_output=$(HOME="$test_root" PROJECT_SESSION_DRY_RUN=1 "$launcher" run projects "$demo_selection")
[[ "$run_output" == *$'DRY-RUN\tchatgpt'* && "$run_output" == *$'DRY-RUN\tterminal'* && \
	"$run_output" != *$'DRY-RUN\tnvim'* ]] || {
	printf 'FAIL: la sesión no delegó en project-session:\n%s\n' "$run_output" >&2
	exit 1
}

mock_bin="$test_root/bin"
notification_log="$test_root/notifications.log"
mkdir -p "$mock_bin"
cat >"$mock_bin/noctalia" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFICATION_LOG"
EOF
chmod +x "$mock_bin/noctalia"

legacy_digest=$(printf '%s' "$project" | sha256sum | cut -c1-12)
legacy_selection="session_demo_${legacy_digest}"$'\t''Sesión Orca + terminal - ~/work/demo'
if ! legacy_output=$(HOME="$test_root" PROJECT_SESSION_DRY_RUN=1 \
	NOTIFICATION_LOG="$notification_log" PATH="$mock_bin:$PATH" \
	"$launcher" run projects "$legacy_selection"); then
	printf '%s\n' 'FAIL: /proj rechazó una selección heredada válida.' >&2
	exit 1
fi
[[ "$legacy_output" == *$'DRY-RUN\tchatgpt'* && "$legacy_output" == *$'DRY-RUN\tterminal'* ]] || {
	printf 'FAIL: la selección heredada no abrió la sesión:\n%s\n' "$legacy_output" >&2
	exit 1
}
[[ ! -s "$notification_log" ]] || {
	printf 'FAIL: la selección heredada válida emitió una notificación:\n%s\n' \
		"$(<"$notification_log")" >&2
	exit 1
}

removed_selection=$'session_missing_000000000000\tSesión Orca + terminal - ~/work/missing'
if ! HOME="$test_root" NOTIFICATION_LOG="$notification_log" PATH="$mock_bin:$PATH" \
	"$launcher" run projects "$removed_selection"; then
	printf '%s\n' 'FAIL: /proj no ignoró una selección obsoleta.' >&2
	exit 1
fi
[[ ! -s "$notification_log" ]] || {
	printf 'FAIL: la selección obsoleta emitió una notificación:\n%s\n' \
		"$(<"$notification_log")" >&2
	exit 1
}

actions_list=$(HOME="$test_root" "$launcher" list project-actions)
for label in 'ChatGPT session and terminal' 'Open ChatGPT' 'Open terminal' 'Open in Nvim' 'Open tasks' 'Open preview'; do
	grep -Fq "$label" <<<"$actions_list" || {
		printf 'FAIL: /proj-actions no publicó %s\n%s\n' "$label" "$actions_list" >&2
		exit 1
	}
done

nvim_selection=$(awk -F '\t' '$1 == "Open in Nvim" { print; exit }' <<<"$actions_list")
[[ -n "$nvim_selection" ]] || {
	printf '%s\n' 'FAIL: no se encontró la acción Nvim.' >&2
	exit 1
}
if HOME="$test_root" PROJECT_SESSION_DRY_RUN=1 "$launcher" run projects "$nvim_selection" >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: /proj aceptó una acción avanzada.' >&2
	exit 1
fi

if rg -q 'session_[A-Za-z0-9_]+_[0-9a-f]{12}' <<<"$project_list$actions_list"; then
	printf '%s\n' 'FAIL: el launcher expuso un identificador interno de proyecto.' >&2
	exit 1
fi

printf '%s\n' 'PASS: /proj abre sesiones y /proj-actions publica acciones seguras'
