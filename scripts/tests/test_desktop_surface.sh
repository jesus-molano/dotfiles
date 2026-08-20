#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
noctalia="$repo_root/noctalia/.config/noctalia/config.toml"
common_binds="$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
desktop_binds="$repo_root/hypr-desktop/.config/hypr/config/user-inputs.lua"

python3 - "$noctalia" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    config = tomllib.load(source)

bar = config["bar"]["default"]
assert "group:resources" in bar["end"]
assert "screen_recorder" in bar["end"]
assert "noctalia/timer:bar" not in bar["end"]
assert "screen_mirror" not in bar["end"]
assert "dev_pulse" not in bar["end"]
assert config["widget"]["ram"]["stat"] == "ram_pct"
assert all("dev-pulse" not in plugin for plugin in config["plugins"]["enabled"])
assert "noctalia/timer" in config["plugins"]["enabled"]
PY

grep -Fq 'bind(hyper .. " + W", hl.dsp.exec_cmd(noctalia .. "wallpaper-next")' "$common_binds"
grep -Fq 'bind(hyper .. " + bracketleft", hl.dsp.exec_cmd(noctalia .. "wallpaper-previous")' "$common_binds"
grep -Fq 'bind(hyper .. " + bracketright", hl.dsp.exec_cmd(noctalia .. "wallpaper-next")' "$common_binds"
grep -Fq 'bind(hyper .. " + T", hl.dsp.exec_cmd("appearance-switch next")' "$common_binds"
grep -Fq 'HYPR_BIND("CONTROL + ALT + SUPER + SHIFT + R", hl.dsp.exec_cmd("local-dictation toggle --paste")' "$desktop_binds"

[[ ! -e "$repo_root/hypr-common/.local/bin/dev-pulse-status" ]]
[[ ! -e "$repo_root/noctalia/.local/share/noctalia/plugins/dev-pulse/plugin.toml" ]]

printf '%s\n' 'PASS: barra limpia, RAM porcentual y atajos W/T/[ ]/R estables'
