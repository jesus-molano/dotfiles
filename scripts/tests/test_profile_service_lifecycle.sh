#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/home"

cat >"$test_root/bin/stow" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'stow\t%s\n' "$*" >>"$TEST_LOG"
if [[ " $* " != *' --simulate '* && "${TEST_STOW_FAIL:-0}" == 1 ]]; then
	exit 1
fi
EOF

cat >"$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
'--user is-enabled reactive-rgb.service' | '--user is-active reactive-rgb.service') exit 0 ;;
esac
printf 'systemctl\t%s\n' "$*" >>"$TEST_LOG"
if [[ "$*" == '--user disable --now reactive-rgb.service' && "${TEST_DISABLE_FAIL:-0}" == 1 ]]; then
	exit 1
fi
EOF
chmod +x "$test_root/bin/"*

log="$test_root/success.log"
PATH="$test_root/bin:$PATH" HOME="$test_root/home" TEST_LOG="$log" \
	just --justfile "$repo_root/justfile" remove hypr-desktop >/dev/null
grep -Fq $'systemctl\t--user disable --now reactive-rgb.service' "$log"
grep -Fq $'systemctl\t--user daemon-reload' "$log"
disable_line=$(grep -n 'disable --now' "$log" | cut -d: -f1)
delete_line=$(grep -n $'stow\t.*--delete --verbose=2' "$log" | cut -d: -f1)
((disable_line < delete_line))

log="$test_root/failure.log"
if PATH="$test_root/bin:$PATH" HOME="$test_root/home" TEST_LOG="$log" TEST_STOW_FAIL=1 \
	just --justfile "$repo_root/justfile" remove hypr-desktop >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: la retirada aceptó un fallo de Stow.' >&2
	exit 1
fi
grep -Fq $'systemctl\t--user enable reactive-rgb.service' "$log"
grep -Fq $'systemctl\t--user start reactive-rgb.service' "$log"

log="$test_root/disable-failure.log"
if PATH="$test_root/bin:$PATH" HOME="$test_root/home" TEST_LOG="$log" TEST_DISABLE_FAIL=1 \
	just --justfile "$repo_root/justfile" remove hypr-desktop >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: la retirada aceptó un fallo parcial de systemd.' >&2
	exit 1
fi
grep -Fq $'systemctl\t--user enable reactive-rgb.service' "$log"
grep -Fq $'systemctl\t--user start reactive-rgb.service' "$log"

# Prueba funcional del despliegue: la función real debe habilitar y reiniciar,
# y restaurar exactamente el estado previo si falla el reinicio.
mkdir -p "$test_root/configure-bin" "$test_root/service-state"
cat >"$test_root/configure-bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl\t%s\n' "$*" >>"$TEST_LOG"
case "$*" in
'--user is-enabled reactive-rgb.service') [[ -e "$TEST_SERVICE_STATE/enabled" ]] ;;
'--user is-active reactive-rgb.service') [[ -e "$TEST_SERVICE_STATE/active" ]] ;;
'--user daemon-reload') ;;
'--user enable reactive-rgb.service')
	[[ ${TEST_ENABLE_FAIL:-0} != 1 ]] || exit 1
	: >"$TEST_SERVICE_STATE/enabled"
	;;
'--user restart reactive-rgb.service')
	[[ ${TEST_RESTART_FAIL:-0} != 1 ]] || exit 1
	: >"$TEST_SERVICE_STATE/active"
	;;
'--user disable --now reactive-rgb.service')
	rm -f -- "$TEST_SERVICE_STATE/enabled" "$TEST_SERVICE_STATE/active"
	;;
'--user start reactive-rgb.service') : >"$TEST_SERVICE_STATE/active" ;;
*) exit 2 ;;
esac
EOF
chmod +x "$test_root/configure-bin/systemctl"

run_configure_service() {
	# El script literal se evalúa dentro del Bash hijo, no en esta prueba.
	# shellcheck disable=SC2016
	env PATH="$test_root/configure-bin:/usr/bin" HOME="$test_root/home" \
		TEST_LOG="$1" TEST_SERVICE_STATE="$test_root/service-state" \
		TEST_ENABLE_FAIL="${TEST_ENABLE_FAIL:-0}" TEST_RESTART_FAIL="${TEST_RESTART_FAIL:-0}" \
		DOTFILES_INSTALL_SOURCE_ONLY=1 bash -c '
			source "$1"
			PROFILE=desktop
			configure_user_services
		' _ "$repo_root/install.sh"
}

: >"$test_root/service-state/enabled"
: >"$test_root/service-state/active"
log="$test_root/configure-success.log"
run_configure_service "$log" >/dev/null
grep -Fq $'systemctl\t--user enable reactive-rgb.service' "$log"
grep -Fq $'systemctl\t--user restart reactive-rgb.service' "$log"
[[ -e "$test_root/service-state/enabled" && -e "$test_root/service-state/active" ]]

log="$test_root/configure-restart-failure.log"
if TEST_RESTART_FAIL=1 run_configure_service "$log" >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: el despliegue aceptó un fallo al reiniciar RGB.' >&2
	exit 1
fi
grep -Fq $'systemctl\t--user disable --now reactive-rgb.service' "$log"
grep -Fq $'systemctl\t--user enable reactive-rgb.service' "$log"
grep -Fq $'systemctl\t--user start reactive-rgb.service' "$log"
[[ -e "$test_root/service-state/enabled" && -e "$test_root/service-state/active" ]]

rm -f -- "$test_root/service-state/enabled" "$test_root/service-state/active"
log="$test_root/configure-enable-failure.log"
if TEST_ENABLE_FAIL=1 run_configure_service "$log" >/dev/null 2>&1; then
	printf '%s\n' 'FAIL: el despliegue aceptó un fallo al habilitar RGB.' >&2
	exit 1
fi
[[ ! -e "$test_root/service-state/enabled" && ! -e "$test_root/service-state/active" ]]

deploy_line=$(grep -n $'^\tdeploy_dotfiles$' "$repo_root/install.sh" | cut -d: -f1)
service_line=$(grep -n $'^\tconfigure_user_services$' "$repo_root/install.sh" | cut -d: -f1)
((deploy_line < service_line))

printf '%s\n' 'PASS: desplegar reinicia RGB y retirar desktop restaura la unidad si Stow falla'
