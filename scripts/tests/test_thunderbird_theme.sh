#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly host="$repo_root/hypr-common/.local/bin/thunderbird-project-atlas-theme-host"
readonly setup="$repo_root/hypr-common/.local/bin/setup-thunderbird-project-atlas-theme"
readonly extension_dir="$repo_root/hypr-common/.local/share/thunderbird-project-atlas-theme"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/config/noctalia/generated" "$test_root/home" "$test_root/state"
cp "$repo_root/noctalia/.config/noctalia/palettes/ProjectAtlas.json" \
	"$test_root/config/noctalia/generated/active-palette.json"

XDG_CONFIG_HOME="$test_root/config" "$host" --once >"$test_root/message.bin"
python3 - "$test_root/message.bin" <<'PY'
import json
from pathlib import Path
import struct
import sys

raw = Path(sys.argv[1]).read_bytes()
size = struct.unpack("<I", raw[:4])[0]
message = json.loads(raw[4:].decode("utf-8"))
assert size == len(raw) - 4
assert message["ok"] is True
assert message["palette"]["mPrimary"] == "#ff5b4d"
assert message["palette"]["mSurface"] == "#14171c"
PY

node --check "$extension_dir/background.js"
python3 -m json.tool "$extension_dir/manifest.json" >/dev/null

HOME="$test_root/home" XDG_STATE_HOME="$test_root/state" \
	THUNDERBIRD_THEME_EXTENSION_DIR="$extension_dir" \
	THUNDERBIRD_THEME_HOST_PATH="$host" \
	"$setup" >"$test_root/xpi-path"

xpi_path=$(<"$test_root/xpi-path")
[[ -f $xpi_path ]]
bsdtar -tf "$xpi_path" | sort >"$test_root/xpi-files"
[[ $(<"$test_root/xpi-files") == $'background.js\nmanifest.json' ]]

manifest="$test_root/home/.mozilla/native-messaging-hosts/com.project_atlas.thunderbird_theme.json"
python3 - "$manifest" "$host" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["path"] == sys.argv[2]
assert manifest["allowed_extensions"] == ["project-atlas-theme@local"]
PY

python3 - "$test_root/state/dotfiles/thunderbird/policies.json" "$xpi_path" <<'PY'
import json
from pathlib import Path
import sys

policy = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
settings = policy["policies"]["ExtensionSettings"]["project-atlas-theme@local"]
assert settings["installation_mode"] == "normal_installed"
assert settings["install_url"] == Path(sys.argv[2]).resolve().as_uri()
assert settings["updates_disabled"] is True
PY

printf '%s\n' 'PASS: host, paleta, XPI, manifiesto nativo y política de instalación'
