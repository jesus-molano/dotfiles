#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
noctalia="$repo_root/noctalia/.config/noctalia/config.toml"
common_binds="$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
desktop_binds="$repo_root/hypr-desktop/.config/hypr/config/user-inputs.lua"
timer_service="$repo_root/noctalia/.local/share/noctalia/plugins/timer/service.luau"

python3 - "$noctalia" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    config = tomllib.load(source)

bar = config["bar"]["default"]
assert "group:resources" in bar["end"]
assert "screen_recorder" in bar["end"]
assert "timer" in bar["end"]
assert "screen_mirror" not in bar["end"]
assert "dev_pulse" not in bar["end"]
assert config["widget"]["ram"]["stat"] == "ram_pct"
assert config["widget"]["timer"]["type"] == "noctalia/timer:bar"
assert config["widget"]["timer"]["show_idle_on_horizontal"] is False
assert all("dev-pulse" not in plugin for plugin in config["plugins"]["enabled"])
assert "noctalia/timer" in config["plugins"]["enabled"]
PY

grep -Fq 'bind(hyper .. " + W", hl.dsp.exec_cmd(noctalia .. "wallpaper-next")' "$common_binds"
grep -Fq 'bind(hyper .. " + bracketleft", hl.dsp.exec_cmd(noctalia .. "wallpaper-previous")' "$common_binds"
grep -Fq 'bind(hyper .. " + bracketright", hl.dsp.exec_cmd(noctalia .. "wallpaper-next")' "$common_binds"
grep -Fq 'bind(hyper .. " + T", hl.dsp.exec_cmd("appearance-switch next")' "$common_binds"
grep -Fq 'bind(hyper .. " + A", hl.dsp.exec_cmd("desktop-launcher open timer")' "$common_binds"
grep -Fq 'HYPR_BIND("CONTROL + ALT + SUPER + SHIFT + R", hl.dsp.exec_cmd("local-dictation toggle --paste")' "$desktop_binds"

grep -Fq 'noctalia.sound.load(ALARM_NAME, ALARM_PATH' "$timer_service"
grep -Fq 'noctalia.sound.play(ALARM_NAME)' "$timer_service"
grep -Fq '/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga' "$timer_service"

[[ ! -e "$repo_root/hypr-common/.local/bin/dev-pulse-status" ]]
[[ ! -e "$repo_root/noctalia/.local/share/noctalia/plugins/dev-pulse/plugin.toml" ]]

printf '%s\n' 'PASS: barra útil, Timer visible y atajos W/T/A/[ ]/R estables'
