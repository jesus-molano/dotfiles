#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
kanata="$repo_root/kanata/.config/kanata/config.kbd"
user_binds="$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
host_binds="$repo_root/hypr-host/.config/hypr/config/hardware-binds.lua"
host_inputs="$repo_root/hypr-host/.config/hypr/config/inputs.lua"
host_user_inputs="$repo_root/hypr-host/.config/hypr/config/user-inputs.lua"
host_monitors="$repo_root/hypr-host/.config/hypr/config/monitors.lua"
generated_host="$repo_root/scripts/dotfiles_host.py"
gaming_binds="$repo_root/gaming-core/.config/hypr/config/gaming.lua"
audio_compat="$repo_root/audio/.local/bin/cycle-desktop-audio-output"

require_text() {
    local file=$1 text=$2
    if ! grep -Fq -- "$text" "$file"; then
        printf 'FAIL: falta contrato %s en %s\n' "$text" "$file" >&2
        exit 1
    fi
}

# Caps remains a dual-role key. The timing is part of the keyboard muscle
# memory, so this deliberately tests the literal Kanata contract without
# requiring uinput, a compositor or a physical keyboard.
require_text "$kanata" '(defsrc'
require_text "$kanata" 'caps a s d f h j k l'
require_text "$kanata" '(tap-hold 150 200 esc (multi lctl lalt lmet lsft))'
require_text "$kanata" '@cap a s d f h j k l'

# The Hyper modifier must continue to be exactly the held Caps modifier.
require_text "$user_binds" 'local hyper = "CONTROL + ALT + SUPER + SHIFT"'

# Alt + H/J/K/L retains focus, move and resize in all four directions.
for direction in \
    'H = { focus = "left", move = "l"' \
    'J = { focus = "down", move = "d"' \
    'K = { focus = "up", move = "u"' \
    'L = { focus = "right", move = "r"'; do
    require_text "$user_binds" "$direction"
done
require_text "$user_binds" 'bind(alt .. " + " .. key, hl.dsp.focus({ direction = direction.focus })'
require_text "$user_binds" 'bind(alt .. " + SHIFT + " .. key,'
require_text "$user_binds" 'bind(alt .. " + CONTROL + " .. key,'

# The eight workspace letters and both focus/move operations are intentional.
require_text "$user_binds" 'local workspace_keys = { "Q", "W", "E", "R", "U", "I", "O", "P" }'
require_text "$user_binds" 'hl.dsp.focus({ workspace = workspace })'
require_text "$user_binds" 'hl.dsp.window.move({ workspace = workspace })'

# Alt+Z belongs to Hyprland's logs scratchpad. Zellij uses a Control-only
# prefix so Hyprland does not intercept either action.
require_text "$user_binds" 'bind(alt .. " + Z", hl.dsp.workspace.toggle_special("logs")'
require_text "$repo_root/zellij/.config/zellij/config.kdl" 'bind "Ctrl g" { SwitchToMode "normal"; }'
if grep -Eq 'bind "Alt (x|z)"' "$repo_root/zellij/.config/zellij/config.kdl"; then
    printf '%s\n' 'FAIL: Zellij no puede reservar Alt+X ni Alt+Z de Hyprland.' >&2
    exit 1
fi

# Every tracked Hyper binding has an explicit regression assertion. Hyper + R
# is rendered only when local dictation is selected and Hyper + G is optional
# with the gaming bundle. Hyper + H remains common across every host.
for key in D comma period semicolon F Return B E Y O M S Space J V bracketleft bracketright T A N H P Q L K 1 C I U 7; do
    require_text "$user_binds" "bind(hyper .. \" + $key\""
done
require_text "$generated_host" 'HYPR_BIND("CONTROL + ALT + SUPER + SHIFT + R"'
require_text "$gaming_binds" 'HYPR_BIND(hyper .. " + G"'
require_text "$user_binds" 'hl.dsp.exec_cmd("cycle-desktop-audio-output")'
require_text "$audio_compat" 'exec cycle-audio-output "$@"'
test -x "$audio_compat"
if grep -Fq 'bind(hyper .. " + W"' "$user_binds" ||
    grep -Fq 'CONTROL + ALT + SUPER + SHIFT + W' "$generated_host"; then
    printf '%s\n' 'FAIL: Hyper+W debe permanecer libre.' >&2
    exit 1
fi

# Fallbacks must stay usable before host detection. They cannot force a device,
# output, audio helper, RGB controller or brightness path.
require_text "$host_inputs" 'follow_mouse = 0'
require_text "$host_user_inputs" 'kb_layout = "us"'
require_text "$host_monitors" 'mode = "preferred"'
require_text "$host_monitors" 'position = "auto"'
require_text "$host_monitors" 'scale = "1"'
require_text "$host_monitors" 'vrr = false'
if grep -Eq 'HYPR_BIND|cycle-desktop-audio-output|Brightness|reactive-rgb' "$host_binds"; then
    printf '%s\n' 'FAIL: el fallback de hardware presupone un adaptador opcional.' >&2
    exit 1
fi

printf '%s\n' 'PASS: Kanata y los atajos Alt/Hyper conservan su contrato portable'
