#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly helper=${1:-"$repo_root/hypr-common/.local/bin/orca-safe-settings"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/config/orca/profiles/test" \
	"$test_root/config/noctalia/generated" "$test_root/config/noctalia/palettes" \
	"$test_root/state"

cat >"$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $1 == clients && $2 == -j ]]
if [[ -n ${TEST_HYPRCTL_SEQUENCE_FILE:-} && -s $TEST_HYPRCTL_SEQUENCE_FILE ]]; then
	head -n 1 "$TEST_HYPRCTL_SEQUENCE_FILE"
	tail -n +2 "$TEST_HYPRCTL_SEQUENCE_FILE" >"$TEST_HYPRCTL_SEQUENCE_FILE.next"
	mv -f "$TEST_HYPRCTL_SEQUENCE_FILE.next" "$TEST_HYPRCTL_SEQUENCE_FILE"
	exit 0
fi
printf '%s\n' "${TEST_HYPRCTL_CLIENTS:?}"
EOF
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$test_root/bin/pgrep"
chmod +x "$test_root/bin/hyprctl" "$test_root/bin/pgrep"
printf '%s\n' '{"settings":{"terminalCustomThemes":[{"id":"manual:project-atlas"},{"id":"keep-me"}]}}' \
	>"$test_root/config/orca/profiles/test/orca-data.json"
jq '.dark.terminal.background = "#010203"' \
	"$repo_root/noctalia/.config/noctalia/palettes/ProjectAtlas.json" \
	>"$test_root/config/noctalia/generated/active-palette.json"
cp "$repo_root/noctalia/.config/noctalia/palettes/ProjectAtlas.json" \
	"$test_root/config/noctalia/palettes/ProjectAtlas.json"

env PATH="$test_root/bin:$PATH" TEST_HYPRCTL_CLIENTS='[]' XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" ORCA_PROFILE=test "$helper" >/dev/null
settings="$test_root/config/orca/profiles/test/orca-data.json"
jq -e '
  .settings.terminalThemeDark == "custom:manual:noctalia-active" and
  ([.settings.terminalCustomThemes[] | select(.id == "manual:noctalia-active")] | length == 1) and
  ([.settings.terminalCustomThemes[] | select(.id == "manual:project-atlas")] | length == 0) and
  (.settings.terminalCustomThemes[] | select(.id == "manual:noctalia-active") | .terminal.background == "#010203")
' "$settings" >/dev/null

before=$(find "$test_root/state/dotfiles/orca" -type f -name 'orca-data.*.json' | wc -l)
env PATH="$test_root/bin:$PATH" TEST_HYPRCTL_CLIENTS='[]' XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" ORCA_PROFILE=test "$helper" >/dev/null
after=$(find "$test_root/state/dotfiles/orca" -type f -name 'orca-data.*.json' | wc -l)
[[ $before -eq 1 && $after -eq 1 ]]

cp "$settings" "$test_root/settings-before-visible-window.json"
env PATH="$test_root/bin:$PATH" \
	TEST_HYPRCTL_CLIENTS='[{"class":"orca","initialClass":"orca"}]' \
	XDG_CONFIG_HOME="$test_root/config" XDG_STATE_HOME="$test_root/state" \
	ORCA_PROFILE=test "$helper" >/dev/null
cmp -s "$test_root/settings-before-visible-window.json" "$settings"

# Si la ventana aparece después del primer sondeo, la segunda validación evita
# escribir ajustes que la UI mantiene ya en memoria.
jq '.dark.terminal.background = "#AABBCC"' \
	"$repo_root/noctalia/.config/noctalia/palettes/ProjectAtlas.json" \
	>"$test_root/config/noctalia/generated/active-palette.json"
printf '%s\n' '[]' '[{"class":"orca","initialClass":"orca"}]' \
	>"$test_root/hyprctl-sequence"
cp "$settings" "$test_root/settings-before-race.json"
env PATH="$test_root/bin:$PATH" TEST_HYPRCTL_CLIENTS='[]' \
	TEST_HYPRCTL_SEQUENCE_FILE="$test_root/hyprctl-sequence" \
	XDG_CONFIG_HOME="$test_root/config" XDG_STATE_HOME="$test_root/state" \
	ORCA_PROFILE=test "$helper" >/dev/null
cmp -s "$test_root/settings-before-race.json" "$settings"

# La paleta generada se puede truncar durante una actualización. El helper
# debe continuar con la fallback válida y no dejar ajustes a medio escribir.
printf '%s\n' '{"dark":{"terminal":' \
	>"$test_root/config/noctalia/generated/active-palette.json"
jq '.dark.terminal.background = "#112233"' \
	"$repo_root/noctalia/.config/noctalia/palettes/ProjectAtlas.json" \
	>"$test_root/config/noctalia/palettes/ProjectAtlas.json"
env PATH="$test_root/bin:$PATH" TEST_HYPRCTL_CLIENTS='[]' XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" ORCA_PROFILE=test "$helper" >/dev/null
jq -e '(.settings.terminalCustomThemes[] | select(.id == "manual:noctalia-active") | .terminal.background) == "#112233"' \
	"$settings" >/dev/null

# Un JSON válido pero incompleto tampoco puede aportar colores a Orca.
jq 'del(.dark.terminal.bright.cyan)' \
	"$repo_root/noctalia/.config/noctalia/palettes/ProjectAtlas.json" \
	>"$test_root/config/noctalia/generated/active-palette.json"
jq '.dark.terminal.background = "#445566"' \
	"$repo_root/noctalia/.config/noctalia/palettes/ProjectAtlas.json" \
	>"$test_root/config/noctalia/palettes/ProjectAtlas.json"
env PATH="$test_root/bin:$PATH" TEST_HYPRCTL_CLIENTS='[]' XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" ORCA_PROFILE=test "$helper" >/dev/null
jq -e '(.settings.terminalCustomThemes[] | select(.id == "manual:noctalia-active") | .terminal.background) == "#445566"' \
	"$settings" >/dev/null

printf '%s\n' 'PASS: Orca usa una paleta valida, conserva el bloqueo por ventana y recurre a ProjectAtlas ante JSON generado invalido'
