#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d)
trap 'find "$test_root" -depth -delete' EXIT
mkdir -p "$test_root/bin" "$test_root/home" "$test_root/config" "$test_root/state" "$test_root/runtime"
chmod 700 "$test_root/runtime"
printf '%s\n' '{"schema":1}' >"$test_root/capabilities.json"

cat >"$test_root/bin/Hyprland" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == --verify-config && "$2" == -c && -f "$3" ]]
[[ $(realpath -e -- "$3") == $(realpath -e -- "$TEST_REPO/hypr-common/.config/hypr/hyprland.lua") ]]
printf 'hypr=%s\n' "$3" >>"$TEST_VALIDATORS"
EOF
cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == config && "$2" == validate && -f "$3/config.toml" ]]
printf 'noctalia=%s\n' "$3" >>"$TEST_VALIDATORS"
EOF
cat >"$test_root/bin/kanata" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == --check && "$2" == -c && -f "$3" ]]
printf 'kanata=%s\n' "$3" >>"$TEST_VALIDATORS"
EOF
chmod +x "$test_root/bin/Hyprland" "$test_root/bin/noctalia" "$test_root/bin/kanata"

before=$(find "$test_root/home" -printf '%y\t%i\t%P\t%l\n' | LC_ALL=C sort)
PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" \
	DOTFILES_REQUIRE_RUNTIME_VALIDATORS=1 TEST_REPO="$repo_root" \
	TEST_VALIDATORS="$test_root/validators.log" \
	"$repo_root/scripts/stow-lint.sh" '' "$test_root/capabilities.json" >"$test_root/lint.out"
after=$(find "$test_root/home" -printf '%y\t%i\t%P\t%l\n' | LC_ALL=C sort)
[[ "$after" == "$before" ]]
grep -Fq 'Hyprland temporal: ' "$test_root/lint.out"
grep -Fq "$repo_root/hypr-common/.config/hypr/hyprland.lua" "$test_root/lint.out"
grep -q '^hypr=' "$test_root/validators.log"
grep -q '^noctalia=' "$test_root/validators.log"
grep -q '^kanata=' "$test_root/validators.log"

printf '%s\n' 'PASS: stow-lint monta hypr-common antes del validador Hyprland'
