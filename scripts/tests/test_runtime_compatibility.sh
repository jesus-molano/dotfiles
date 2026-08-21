#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d)
trap 'find "$test_root" -depth -delete' EXIT
mkdir -p "$test_root/bin" "$test_root/home" "$test_root/state"

cat >"$test_root/bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode=$1
package=${!#}
case "$mode" in
-Q)
	version=$(awk -F '\t' -v package="$package" '$1 == package { print $2; found = 1; exit } END { exit !found }' "$TEST_INSTALLED")
	printf '%s %s\n' "$package" "$version"
	;;
-Sp)
	awk -F '\t' -v package="$package" '$1 == package { print $2; found = 1; exit } END { exit !found }' "$TEST_AVAILABLE"
	;;
*) exit 2 ;;
esac
EOF
chmod +x "$test_root/bin/pacman"

cat >"$test_root/plan.json" <<'EOF'
{
  "compatibility": {
    "packages": {
      "cachyos-hypr-noctalia": {"minimum": "1.2.5", "source": "native"},
      "hyprland": {"minimum": "0.56.2", "source": "native"},
      "kanata-bin": {"minimum": "1.12.0", "source": "aur"},
      "noctalia": {"minimum": "5.0.0_beta.9", "stable_minimum": "5.0.0", "source": "native"}
    }
  }
}
EOF

cat >"$test_root/current.tsv" <<'EOF'
cachyos-hypr-noctalia	1.2.5-1
hyprland	0.56.2-1
kanata-bin	1.12.0-1
noctalia	5.1.0-1
EOF
cp "$test_root/current.tsv" "$test_root/available.tsv"

runner="$test_root/run.sh"
cat >"$runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$TEST_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
check_runtime_compatibility "$TEST_MODE"
EOF
chmod +x "$runner"

PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" \
	TEST_REPO="$repo_root" TEST_PLAN="$test_root/plan.json" TEST_MODE=installed \
	TEST_INSTALLED="$test_root/current.tsv" TEST_AVAILABLE="$test_root/available.tsv" \
	"$runner" >/dev/null

# La comprobación real acepta tanto una beta posterior como la primera release
# estable. Pacman ordena 5.0.0 por debajo de 5.0.0_beta.9, por lo que ambas ramas
# deben usar los suelos explícitos del contrato.
for accepted in 5.0.0_beta.10-1 5.0.0-1 5.1.0-1; do
	sed "s/5\\.1\\.0-1/$accepted/" "$test_root/current.tsv" >"$test_root/accepted.tsv"
	PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" \
		TEST_REPO="$repo_root" TEST_PLAN="$test_root/plan.json" TEST_MODE=installed \
		TEST_INSTALLED="$test_root/accepted.tsv" TEST_AVAILABLE="$test_root/available.tsv" \
		"$runner" >/dev/null
done

# Un runtime antiguo se rechaza aunque el repositorio ya tenga uno nuevo.
sed 's/5\.1\.0-1/5.0.0_beta.8-1/' "$test_root/current.tsv" >"$test_root/old.tsv"
if PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" \
	TEST_REPO="$repo_root" TEST_PLAN="$test_root/plan.json" TEST_MODE=available \
	TEST_INSTALLED="$test_root/old.tsv" TEST_AVAILABLE="$test_root/available.tsv" \
	"$runner" >"$test_root/old.out" 2>&1; then
	printf '%s\n' 'FAIL: se aceptó Noctalia por debajo del mínimo.' >&2
	exit 1
fi
grep -Fq 'anterior al mínimo compatible 5.0.0_beta.9' "$test_root/old.out"

# En un host nuevo se comprueban los candidatos nativos. Kanata AUR queda
# diferido hasta que Shelly lo compile y el segundo check estricto lo compruebe.
: >"$test_root/empty.tsv"
PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" \
	TEST_REPO="$repo_root" TEST_PLAN="$test_root/plan.json" TEST_MODE=available \
	TEST_INSTALLED="$test_root/empty.tsv" TEST_AVAILABLE="$test_root/available.tsv" \
	"$runner" >"$test_root/available.out"
grep -Fq 'diferida hasta que Shelly compile' "$test_root/available.out"

# Añadir cualquier paquete fuerza primero una actualización estándar completa.
# Esto cubre también el caso en que solo falta un AUR: sus dependencias nativas
# nunca se instalan contra un sistema Arch parcialmente actualizado.
cat >"$test_root/bin/shelly" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_SHELLY_CALLS"
EOF
chmod +x "$test_root/bin/shelly"

cat >"$test_root/install-packages.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$TEST_REPO/install.sh"
collect_packages() {
	case "$1" in
	native) printf '%s\n' "${TEST_NATIVE_PACKAGE:-native-present}" ;;
	aur) printf '%s\n' "${TEST_AUR_PACKAGE:-aur-missing}" ;;
	esac
}
install_packages
EOF
chmod +x "$test_root/install-packages.sh"
: >"$test_root/shelly.calls"
cat >"$test_root/installed-packages.tsv" <<'EOF'
native-present	1.0-1
EOF
PATH="$test_root/bin:/usr/bin" HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" \
	DISPLAY='' WAYLAND_DISPLAY='' TEST_REPO="$repo_root" TEST_INSTALLED="$test_root/installed-packages.tsv" \
	TEST_AVAILABLE="$test_root/available.tsv" TEST_SHELLY_CALLS="$test_root/shelly.calls" \
	"$test_root/install-packages.sh" >/dev/null
sed -n '1p' "$test_root/shelly.calls" | grep -Fxq 'upgrade standard'
sed -n '2p' "$test_root/shelly.calls" | grep -Fxq 'install aur aur-missing'

# Con un paquete nativo faltante, Shelly combina la actualización completa y
# su instalación en una sola transacción soportada.
: >"$test_root/shelly.calls"
cat >"$test_root/native-missing.tsv" <<'EOF'
aur-present	1.0-1
EOF
PATH="$test_root/bin:/usr/bin" HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" \
	DISPLAY='' WAYLAND_DISPLAY='' TEST_REPO="$repo_root" TEST_INSTALLED="$test_root/native-missing.tsv" \
	TEST_AVAILABLE="$test_root/available.tsv" TEST_SHELLY_CALLS="$test_root/shelly.calls" \
	TEST_NATIVE_PACKAGE=native-missing TEST_AUR_PACKAGE=aur-present \
	"$test_root/install-packages.sh" >/dev/null
sed -n '1p' "$test_root/shelly.calls" | grep -Fxq 'install standard --upgrade native-missing'
[[ $(wc -l <"$test_root/shelly.calls") -eq 1 ]]

# Stow despliega .config dentro de HOME. El instalador debe rechazar un XDG
# alternativo antes de crear host.toml, estado o paquetes.
cat >"$test_root/xdg-layout.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$TEST_REPO/install.sh"
validate_xdg_config_layout
EOF
chmod +x "$test_root/xdg-layout.sh"
HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/home/.config/" TEST_REPO="$repo_root" \
	"$test_root/xdg-layout.sh"
if HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/custom-config" TEST_REPO="$repo_root" \
	"$test_root/xdg-layout.sh" >"$test_root/xdg.out" 2>&1; then
	printf '%s\n' 'FAIL: se aceptó un XDG_CONFIG_HOME que Stow no puede desplegar.' >&2
	exit 1
fi
grep -Fq 'XDG_CONFIG_HOME personalizado no está soportado' "$test_root/xdg.out"
[[ ! -e "$test_root/custom-config" ]]

printf '%s\n' 'PASS: mínimos sin pins, transición estable y actualización Arch completa'
