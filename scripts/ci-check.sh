#!/usr/bin/env bash
# Suite reproducible para CI: valida contratos que no necesitan hardware,
# sesión gráfica, secretos, paquetes AUR ni acceso administrativo.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_root"

run() {
	local label=$1
	shift
	printf '==> %s\n' "$label"
	"$@"
}

mapfile -t shell_files < <(
	git grep -Il \
		-e '^#!/usr/bin/env bash' \
		-e '^#!/usr/bin/bash' \
		-e '^#!/bin/bash' \
		-e '^#!/bin/sh' --
)
((${#shell_files[@]})) || {
	printf '%s\n' 'No se encontraron scripts Shell versionados.' >&2
	exit 1
}
run 'Sintaxis y contratos de todos los scripts Shell versionados' \
	shellcheck -x "${shell_files[@]}"
run 'Sintaxis Python' python3 -c \
	'import ast,pathlib; [ast.parse(path.read_text(encoding="utf-8"), filename=str(path)) for path in pathlib.Path("scripts").rglob("*.py")]'
run 'Sintaxis Fish Android' fish -n android/.config/fish/conf.d/android.fish
run 'Configuración Zellij' env -u ZELLIJ_CONFIG_FILE ZELLIJ_CONFIG_DIR="$repo_root/zellij/.config/zellij" \
	zellij setup --check
run 'Pruebas Python' env PYTHONDONTWRITEBYTECODE=1 \
	python3 -m unittest discover -s scripts/tests -p 'test_*.py'
run 'Generación de temas terminales y Micro' env PYTHONDONTWRITEBYTECODE=1 \
	python3 scripts/tests/test_terminal_theme_generation.py

for test in \
	test_dotf_function.sh \
	test_runtime_compatibility.sh \
	test_keyboard_contract.sh \
	test_brave_browser_contract.sh \
	test_appearance_switch.sh \
	test_setup_brave_theme_policy.sh \
	test_desktop_surface.sh \
	test_thunderbird_theme.sh \
	test_stow_lint.sh \
	test_install_transaction.sh \
	test_backup_portable.sh \
	test_system_etc_transaction.sh \
	test_game_run_dnd.sh \
	test_demo_studio.sh \
	test_orca_background.sh \
	test_chatgpt_background.sh \
	test_auto_route_audio.sh \
	test_android_environment.sh; do
	run "$test" bash "scripts/tests/$test"
done

run 'Whitespace Git' git diff --check
run 'Whitespace del commit Git' git show --check --format= HEAD
printf '%s\n' 'CI reproducible completado.'
