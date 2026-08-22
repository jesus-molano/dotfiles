#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fish_config="$repo_root/fish/.config/fish/config.fish"
noctalia="$repo_root/noctalia/.config/noctalia/config.toml"
productivity="$repo_root/productivity-extra/.config/noctalia/zz-productivity-extra.toml"
common_binds="$repo_root/hypr-common/.config/hypr/config/user-binds.lua"
timer_service="$repo_root/noctalia/.local/share/noctalia/plugins/timer/service.luau"
timer_manifest="$repo_root/noctalia/.local/share/noctalia/plugins/timer/plugin.toml"
dap_configs="$repo_root/nvim/.config/nvim/lua/plugins/dap-configs.lua"

python3 - "$noctalia" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as source:
    config = tomllib.load(source)

bar = config["bar"]["default"]
assert config["audio"]["enable_sounds"] is True
assert config["audio"]["sound_volume"] == 0.65
assert "group:resources" in bar["end"]
assert "codexbar" not in bar["end"]
assert "screen_recorder" in bar["end"]
assert "timer" in bar["end"]
assert "screen_mirror" not in bar["end"]
assert "dev_pulse" not in bar["end"]
assert config["widget"]["ram"]["stat"] == "ram_pct"
assert config["widget"]["timer"]["type"] == "noctalia/timer:bar"
assert config["widget"]["timer"]["show_idle_on_horizontal"] is False
assert "codexbar" not in config["widget"]
assert all("dev-pulse" not in plugin for plugin in config["plugins"]["enabled"])
assert "noctalia/timer" in config["plugins"]["enabled"]
assert "salemsayed/codexbar-meter" not in config["plugins"]["enabled"]
assert "noctalia/notes" in config["plugins"]["enabled"]
notes = config["plugin_settings"]["noctalia/notes"]
assert notes["notes_dir"] == "~/Documents/Notes"
assert notes["extension"] == "md"
assert "salemsayed/codexbar-meter" not in config["plugin_settings"]
assert config["plugins"]["auto_update"] == "none"
assert config["shell"]["avatar_path"].endswith("/avatar.svg")
PY

if command -v noctalia >/dev/null 2>&1; then
	test_root=$(mktemp -d)
	trap 'rm -rf -- "$test_root"' EXIT
	mkdir -p -- "$test_root/home" "$test_root/config/noctalia" \
		"$test_root/state" "$test_root/data" "$test_root/cache"
	cp -- "$noctalia" "$test_root/config/noctalia/config.toml"
	cp -- "$productivity" "$test_root/config/noctalia/zz-productivity-extra.toml"
	merged=$(
		env HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
			XDG_STATE_HOME="$test_root/state" XDG_DATA_HOME="$test_root/data" \
			XDG_CACHE_HOME="$test_root/cache" noctalia config export merged
	)
	python3 -c '
import sys, tomllib
config = tomllib.loads(sys.stdin.read())
assert "codexbar" in config["bar"]["default"]["end"]
assert config["widget"]["codexbar"]["type"] == "salemsayed/codexbar-meter:bar"
assert "salemsayed/codexbar-meter" in config["plugins"]["enabled"]
settings = config["plugin_settings"]["salemsayed/codexbar-meter"]
assert settings["codexbarPath"] == "/usr/bin/codexbar"
assert settings["refreshIntervalSec"] == 300
assert settings["barProviderLimit"] == 1
' <<<"$merged"
else
	printf '%s\n' 'SKIP: merge Noctalia requiere el runtime; los contratos TOML estáticos continúan validados.'
fi

if grep -Fq 'bind(hyper .. " + W",' "$common_binds"; then
	printf '%s\n' 'Hyper+W debe quedar libre.' >&2
	exit 1
fi
grep -Fq 'if status is-interactive; and command -q mise' "$fish_config"
grep -Fq 'bind(hyper .. " + bracketleft", hl.dsp.exec_cmd(noctalia .. "wallpaper-previous")' "$common_binds"
grep -Fq 'bind(hyper .. " + bracketright", hl.dsp.exec_cmd(noctalia .. "wallpaper-next")' "$common_binds"
grep -Fq 'bind(hyper .. " + T", hl.dsp.exec_cmd(noctalia .. "panel-open launcher /appearance")' "$common_binds"
grep -Fq 'bind(hyper .. " + A", hl.dsp.exec_cmd("desktop-launcher open timer")' "$common_binds"
grep -Fq 'panel-toggle control-center' "$common_binds"

python3 - "$repo_root" <<'PY'
import importlib.util
import sys
from pathlib import Path

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("dotfiles_host", root / "scripts/dotfiles_host.py")
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)
generated = module.generated_hypr({
    "bundles": ["local-ai"],
    "input": {"keyboard_layouts": ["us", "es"], "local_dictation": True},
    "audio": {"cycle": True},
    "workspaces": {},
})
assert 'local-dictation toggle --paste' in generated["user-inputs.lua"]
assert 'cycle-audio-output' not in generated["hardware-binds.lua"]
without_bundle = module.generated_hypr({
    "bundles": [],
    "input": {"keyboard_layouts": ["us", "es"], "local_dictation": True},
    "audio": {},
    "workspaces": {},
})
assert 'local-dictation toggle --paste' not in without_bundle["user-inputs.lua"]
PY

grep -Fq 'noctalia.sound.load(ALARM_NAME, ALARM_PATH' "$timer_service"
grep -Fq 'noctalia.sound.play(ALARM_NAME)' "$timer_service"
grep -Fq 'event == "preview-alarm"' "$timer_service"
grep -Fq '/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga' "$timer_service"
grep -Fq 'plugin_api = 20' "$timer_manifest"
grep -Fq 'name = "Vite: dev server (Brave)"' "$dap_configs"
grep -Fq 'runtimeExecutable = brave ~= "" and brave or "/usr/bin/brave"' "$dap_configs"

[[ ! -e "$repo_root/hypr-common/.local/bin/dev-pulse-status" ]]
[[ ! -e "$repo_root/noctalia/.local/share/noctalia/plugins/dev-pulse/plugin.toml" ]]

printf '%s\n' 'PASS: barra útil, Notes, Timer visible y paneles T/A/[ ]/R estables'
