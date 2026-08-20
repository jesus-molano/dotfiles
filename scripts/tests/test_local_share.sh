#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly share=${1:-"$repo_root/hypr-common/.local/bin/local-share"}
readonly launcher=${2:-"$repo_root/hypr-common/.local/bin/desktop-launcher"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/runtime"

cat >"$test_root/bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >>"$TEST_SYSTEMD_LOG"
EOF

cat >"$test_root/bin/wl-paste" <<'EOF'
#!/usr/bin/env bash
printf '%s' 'clipboard payload'
EOF

cat >"$test_root/bin/localsend" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >>"$TEST_LOCALSEND_LOG"
EOF

cat >"$test_root/bin/zenity" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$TEST_PICKED_PATH"
EOF

cat >"$test_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_NOCTALIA_LOG"
EOF

chmod +x "$test_root/bin/"*
ln -s "$share" "$test_root/bin/local-share"
: >"$test_root/systemd.log"
: >"$test_root/localsend.log"
: >"$test_root/noctalia.log"

PATH="$test_root/bin:$PATH" XDG_RUNTIME_DIR="$test_root/runtime" \
	TEST_SYSTEMD_LOG="$test_root/systemd.log" "$share" clipboard

mapfile -d '' -t systemd_args <"$test_root/systemd.log"
[[ ${systemd_args[*]} == *'--user --quiet --collect --'* ]]
[[ ${systemd_args[-2]} == '__send-clipboard' ]]
clipboard_file=${systemd_args[-1]}
[[ -f "$clipboard_file" ]]
[[ $(<"$clipboard_file") == 'clipboard payload' ]]

PATH="$test_root/bin:$PATH" XDG_RUNTIME_DIR="$test_root/runtime" \
	TEST_LOCALSEND_LOG="$test_root/localsend.log" \
	"$share" __send-clipboard "$clipboard_file"
[[ ! -e "$clipboard_file" ]]
mapfile -d '' -t localsend_args <"$test_root/localsend.log"
[[ ${localsend_args[*]} == "--headless send $clipboard_file" ]]

picked_file="$test_root/example file.txt"
printf '%s\n' demo >"$picked_file"
: >"$test_root/systemd.log"
PATH="$test_root/bin:$PATH" TEST_PICKED_PATH="$picked_file" \
	TEST_SYSTEMD_LOG="$test_root/systemd.log" "$share" file
mapfile -d '' -t systemd_args <"$test_root/systemd.log"
[[ ${systemd_args[*]} == "--user --quiet --collect -- localsend --headless send $picked_file" ]]

: >"$test_root/systemd.log"
PATH="$test_root/bin:$PATH" TEST_SYSTEMD_LOG="$test_root/systemd.log" \
	"$share" folder "$test_root"
mapfile -d '' -t systemd_args <"$test_root/systemd.log"
[[ ${systemd_args[*]} == "--user --quiet --collect -- localsend --headless send $test_root" ]]

entries=$(PATH="$test_root/bin:$PATH" "$launcher" list share)
[[ $entries == $'Clipboard\tSend copied text\nFiles\tChoose one or more files\nFolder\tChoose a folder' ]]
: >"$test_root/systemd.log"
selection=$(grep '^Files'$'\t' <<<"$entries")
PATH="$test_root/bin:$PATH" TEST_PICKED_PATH="$picked_file" \
	TEST_SYSTEMD_LOG="$test_root/systemd.log" "$launcher" run share "$selection"
mapfile -d '' -t systemd_args <"$test_root/systemd.log"
[[ ${systemd_args[-1]} == "$picked_file" ]]

python3 - "$repo_root" <<'PY'
from pathlib import Path
import sys
import tomllib

root = Path(sys.argv[1])
with (root / "noctalia/.config/noctalia/config.toml").open("rb") as source:
    entry = tomllib.load(source)["shell"]["launcher"]["dmenu"]["entry"]["share"]
assert entry["prefix"] == "share"
assert entry["label"] == "Share"
assert entry["glyph"] == "share-2"
assert entry["exec"] == 'desktop-launcher run share "{selection}"'

service = root / "hypr-common/.local/share/kio/servicemenus/localsend.desktop"
assert service.stat().st_mode & 0o111
text = service.read_text(encoding="utf-8")
assert "MimeType=all/allfiles;inode/directory;" in text
assert "Exec=local-share file %F" in text
PY

printf '%s\n' 'PASS: LocalSend conserva argumentos, limpia el portapapeles y expone /share y Dolphin'
