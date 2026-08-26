#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly setup_source=${1:-"$repo_root/hypr-common/.local/bin/setup-brave-project-atlas-policy"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
readonly setup="$test_root/setup-brave-project-atlas-policy-test"

mkdir -p "$test_root/bin" "$test_root/state/dotfiles/appearance-switch/brave-policies/managed"
printf '{"BrowserThemeColor":"#f77e9c"}\n' \
	>"$test_root/state/dotfiles/appearance-switch/brave-policies/managed/project-atlas-theme.json"

cat >"$test_root/bin/pkexec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command=$1
shift
if [[ $command == /usr/bin/install ]]; then
	args=()
	while (($#)); do
		case "$1" in
		-o | -g) shift 2 ;;
		*) args+=("$1"); shift ;;
		esac
	done
	exec "$command" "${args[@]}"
fi
exec "$command" "$@"
EOF
cat >"$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_SYSTEMCTL_LOG"
case "${1:-}" in
start)
	mkdir -p -- "${TEST_POLICY_TARGET%/*}"
	cp -- "$TEST_POLICY_SOURCE" "$TEST_POLICY_TARGET"
	;;
is-enabled | is-active)
	[[ ${TEST_SYSTEMCTL_INACTIVE:-0} != 1 ]]
	;;
esac
EOF
chmod +x "$test_root/bin/pkexec" "$test_root/bin/systemctl"

# La copia efímera sustituye las rutas literales. El ejecutable desplegable no
# contiene hooks de entorno que puedan alcanzar Polkit.
sed \
	-e "s|^readonly policy_root=.*|readonly policy_root='$test_root/etc/brave/policies'|" \
	-e "s|^readonly systemd_dir=.*|readonly systemd_dir='$test_root/etc/systemd/system'|" \
	-e "s|^readonly libexec_dir=.*|readonly libexec_dir='$test_root/usr/local/libexec'|" \
	-e "s|^readonly install_state_dir=.*|readonly install_state_dir='$test_root/var/lib/project-atlas-brave-policy'|" \
	-e "s|^readonly pkexec_cmd=.*|readonly pkexec_cmd='$test_root/bin/pkexec'|" \
	-e "s|^readonly systemctl_cmd=.*|readonly systemctl_cmd='$test_root/bin/systemctl'|" \
	-e "s|^readonly helper_source=.*|readonly helper_source='$repo_root/hypr-common/.local/libexec/project-atlas-brave-policy-sync'|" \
	"$setup_source" >"$setup"
chmod +x "$setup"

run() {
	TEST_SYSTEMCTL_LOG="$test_root/systemctl.log" \
		XDG_STATE_HOME="$test_root/state" \
		TEST_POLICY_SOURCE="$test_root/state/dotfiles/appearance-switch/brave-policies/managed/project-atlas-theme.json" \
		TEST_POLICY_TARGET="$test_root/etc/brave/policies/managed/project-atlas-theme.json" \
		TEST_SYSTEMCTL_INACTIVE="${TEST_SYSTEMCTL_INACTIVE:-0}" \
		"$setup" "$@"
}

[[ $(run --check) == +*'pendiente, desactualizada o incompleta'* ]]
run --install >/dev/null
[[ -f "$test_root/etc/systemd/system/project-atlas-brave-policy.path" ]]
[[ -f "$test_root/etc/systemd/system/project-atlas-brave-policy.service" ]]
[[ -x "$test_root/usr/local/libexec/project-atlas-brave-policy-sync" ]]
[[ ! -L "$test_root/etc/brave/policies/managed" ]]
[[ $(<"$test_root/var/lib/project-atlas-brave-policy/installation") == \
	'project-atlas-brave-policy:v1' ]]
grep -Fq "PathChanged=$test_root/state/" \
	"$test_root/etc/systemd/system/project-atlas-brave-policy.path"
grep -Fq 'enable --now project-atlas-brave-policy.path' "$test_root/systemctl.log"
if command -v systemd-analyze >/dev/null 2>&1; then
	systemd-analyze verify \
		"$test_root/etc/systemd/system/project-atlas-brave-policy.service" \
		"$test_root/etc/systemd/system/project-atlas-brave-policy.path"
fi
[[ $(run --check) == =*'instalada'* ]]
[[ $(TEST_SYSTEMCTL_INACTIVE=1 run --check) == +*'desactualizada o incompleta'* ]]

# Una revisión propia anterior se actualiza gracias al marcador root.
printf '%s\n' 'version anterior' >"$test_root/usr/local/libexec/project-atlas-brave-policy-sync"
run --install >/dev/null
cmp -s "$repo_root/hypr-common/.local/libexec/project-atlas-brave-policy-sync" \
	"$test_root/usr/local/libexec/project-atlas-brave-policy-sync"

# El rollback sigue disponible si desaparece la fuente mutable.
rm -f -- "$test_root/state/dotfiles/appearance-switch/brave-policies/managed/project-atlas-theme.json"
run --remove >/dev/null
[[ ! -e "$test_root/etc/systemd/system/project-atlas-brave-policy.path" ]]
[[ ! -e "$test_root/usr/local/libexec/project-atlas-brave-policy-sync" ]]

# Una instalación parcial marcada se puede retirar.
mkdir -p "$test_root/usr/local/libexec"
cp -- "$repo_root/hypr-common/.local/libexec/project-atlas-brave-policy-sync" \
	"$test_root/usr/local/libexec/project-atlas-brave-policy-sync"
mkdir -p "$test_root/var/lib/project-atlas-brave-policy"
printf '%s\n' 'project-atlas-brave-policy:v1' \
	>"$test_root/var/lib/project-atlas-brave-policy/installation"
run --remove >/dev/null

# Una política válida pero ajena no se adopta ni se sobrescribe.
mkdir -p "$test_root/etc/brave/policies/managed"
printf '{"BrowserThemeColor":"#123456"}\n' \
	>"$test_root/etc/brave/policies/managed/project-atlas-theme.json"
printf '{"BrowserThemeColor":"#f77e9c"}\n' \
	>"$test_root/state/dotfiles/appearance-switch/brave-policies/managed/project-atlas-theme.json"
if run --install >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: adoptó una política válida pero ajena.' >&2
	exit 1
fi
[[ $(jq -r '.BrowserThemeColor' "$test_root/etc/brave/policies/managed/project-atlas-theme.json") == '#123456' ]]

# Un helper ajeno también se conserva.
rm -f -- "$test_root/etc/brave/policies/managed/project-atlas-theme.json"
printf '%s\n' 'ajeno' >"$test_root/usr/local/libexec/project-atlas-brave-policy-sync"
if run --remove >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: retiró un helper ajeno.' >&2
	exit 1
fi
[[ $(<"$test_root/usr/local/libexec/project-atlas-brave-policy-sync") == ajeno ]]

printf '%s\n' 'PASS: política de Brave automática, acotada y reversible'
