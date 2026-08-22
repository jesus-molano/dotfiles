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

run 'Sintaxis y contratos Shell' shellcheck -x \
	install.sh \
	scripts/ci-check.sh \
	scripts/stow-lint.sh \
	scripts/system-etc-transaction.sh \
	backup/.local/bin/dotfiles-backup \
	gaming-core/.local/bin/game-run \
	hypr-common/.local/bin/demo-studio \
	hypr-common/.local/bin/start-orca-background \
	android/.local/bin/android-sdk-check \
	scripts/tests/test_android_environment.sh
run 'Sintaxis Python' python3 -c \
	'import ast,pathlib; [ast.parse(path.read_text(encoding="utf-8"), filename=str(path)) for path in pathlib.Path("scripts").rglob("*.py")]'
run 'Sintaxis Fish Android' fish -n android/.config/fish/conf.d/android.fish
run 'Configuración Zellij' env ZELLIJ_CONFIG_FILE="$repo_root/zellij/.config/zellij/config.kdl" \
	zellij setup --check
run 'Pruebas Python' env PYTHONDONTWRITEBYTECODE=1 \
	python3 -m unittest discover -s scripts/tests -p 'test_*.py'

for test in \
	test_dotf_function.sh \
	test_runtime_compatibility.sh \
	test_keyboard_contract.sh \
	test_desktop_surface.sh \
	test_stow_lint.sh \
	test_install_transaction.sh \
	test_backup_portable.sh \
	test_system_etc_transaction.sh \
	test_game_run_dnd.sh \
	test_demo_studio.sh \
	test_orca_background.sh \
	test_android_environment.sh; do
	run "$test" bash "scripts/tests/$test"
done

run 'Whitespace Git' git diff --check
printf '%s\n' 'CI reproducible completado.'
