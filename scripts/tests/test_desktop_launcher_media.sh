#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
readonly launcher=${1:-"$repo_root/hypr-common/.local/bin/desktop-launcher"}
readonly stremio=${2:-"$repo_root/hypr-common/.local/bin/hypr-stremio"}
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/uwsm" <<'EOF'
#!/usr/bin/env bash
printf 'uwsm\t%s\n' "$*" >>"$TEST_LOG"
EOF
cat >"$test_root/bin/hypr-stremio" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' stremio >>"$TEST_LOG"
EOF
cat >"$test_root/bin/hypr-spotify" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' spotify >>"$TEST_LOG"
EOF
chmod +x "$test_root/bin/uwsm" "$test_root/bin/hypr-stremio" "$test_root/bin/hypr-spotify"

media=$(PATH="$test_root/bin:$PATH" "$launcher" list media)
expected_media=$'Stremio\tMovies and series\nYouTube\tVideos\nYouTube subscriptions\tVideos from followed channels\nSpotify\tMusic and podcasts'
[[ "$media" == "$expected_media" ]]

log="$test_root/media.log"
: >"$log"
while IFS= read -r selection; do
	PATH="$test_root/bin:$PATH" TEST_LOG="$log" "$launcher" run media "$selection"
done <<<"$media"
expected=$(cat <<'EOF'
stremio
uwsm	app -- qutebrowser https://www.youtube.com/
uwsm	app -- qutebrowser https://www.youtube.com/feed/subscriptions
spotify
EOF
)
[[ "$(<"$log")" == "$expected" ]]

# El helper enfoca una superficie existente y no abre otra instancia.
cat >"$test_root/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == 'clients -j' ]]; then
	printf '%s\n' "${TEST_STREMIO_CLIENTS:-[]}"
else
	printf 'hyprctl\t%s\n' "$*" >>"$TEST_LOG"
fi
EOF
chmod +x "$test_root/bin/hyprctl"
: >"$log"
PATH="$test_root/bin:$PATH" TEST_LOG="$log" \
	TEST_STREMIO_CLIENTS='[{"class":"com.stremio.Stremio","initialClass":"","address":"0xabc"}]' \
	"$stremio"
[[ "$(<"$log")" == $'hyprctl\teval hl.dispatch(hl.dsp.focus({ window = "class:^(com\\\\.stremio\\\\.Stremio|[Ss]tremio)$" }))' ]]

: >"$log"
PATH="$test_root/bin:$PATH" TEST_LOG="$log" TEST_STREMIO_CLIENTS='[]' "$stremio"
[[ "$(<"$log")" == $'uwsm\tapp -- flatpak --user run com.stremio.Stremio' ]]

printf '%s\n' 'PASS: /media abre Stremio, Spotify y YouTube sin duplicar Stremio'
