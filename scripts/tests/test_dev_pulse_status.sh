#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/dev-pulse-status"}
test_root=$(mktemp -d)
terminal_pid=''

cleanup() {
	if [[ "$terminal_pid" =~ ^[0-9]+$ ]] && kill -0 "$terminal_pid" 2>/dev/null; then
		kill "$terminal_pid" 2>/dev/null || true
		wait "$terminal_pid" 2>/dev/null || true
	fi
	rm -rf -- "$test_root"
}
trap cleanup EXIT

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

cat >"$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '{"pid":%s}\n' "${DEV_PULSE_TEST_PID:?}"
EOF
chmod +x "$test_root/bin/hyprctl"

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

# Hyprland reports the terminal window PID. Ghostty itself can remain in HOME
# while its Zellij or shell child owns the actual project directory.
(
	cd "$test_root"
	sh -c 'cd "$1" && exec sleep 30' sh "$project" &
	child_pid=$!
	trap 'kill "$child_pid" 2>/dev/null || true' EXIT
	wait "$child_pid"
) &
terminal_pid=$!

for _ in {1..50}; do
	children_file="/proc/$terminal_pid/task/$terminal_pid/children"
	[[ -r "$children_file" && -n "$(<"$children_file")" ]] && break
	sleep 0.02
done

terminal_status=$(env -u DEV_PULSE_PROJECT_DIR \
	DEV_PULSE_TEST_PID="$terminal_pid" PATH="$test_root/bin:$PATH" \
	"$helper" --json)
jq -e --arg path "$project" \
	'.available == true and .path == $path and .project == "project"' \
	<<<"$terminal_status" >/dev/null || {
	printf 'FAIL: no detectó el repositorio del proceso hijo del terminal: %s\n' "$terminal_status" >&2
	exit 1
}

printf '%s\n' 'PASS: Dev Pulse identifica el proyecto activo y el estado local'
