#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/dev-pulse-status"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

project="$test_root/project"
mkdir -p "$project" "$test_root/bin"
git -C "$project" init --quiet --initial-branch=pulse-test
git -C "$project" config user.email test@example.invalid
git -C "$project" config user.name test
touch "$project/tracked"
git -C "$project" add tracked
git -C "$project" commit --quiet -m initial
touch "$project/untracked"

cat >"$test_root/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
*codex*) printf '2\n' ;;
*orca-ide*) printf '1\n' ;;
*) exit 1 ;;
esac
EOF
chmod +x "$test_root/bin/pgrep"

actual=$(DEV_PULSE_PROJECT_DIR="$project" PATH="$test_root/bin:$PATH" "$helper" --json)
jq -e \
	--arg project project \
	--arg path "$project" \
	'.available == true and .project == $project and .path == $path and .branch == "pulse-test" and .dirty == 1 and .dirty_available == true and .codex == 2 and .orca == 1' \
	<<<"$actual" >/dev/null || {
	printf 'FAIL: estado Dev Pulse inesperado: %s\n' "$actual" >&2
	exit 1
}

rm -f -- "$project/untracked"
clean=$(DEV_PULSE_PROJECT_DIR="$project" PATH="$test_root/bin:$PATH" "$helper" --json)
jq -e '.available == true and .dirty_available == true and .dirty == 0' \
	<<<"$clean" >/dev/null || {
	printf 'FAIL: un repositorio limpio no devolvió cero cambios: %s\n' "$clean" >&2
	exit 1
}

printf '%s\n' 'PASS: Dev Pulse identifica el proyecto activo y el estado local'
