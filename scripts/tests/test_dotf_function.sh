#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
function_file="$repo_root/fish/.config/fish/functions/dotf.fish"
completion_file="$repo_root/fish/.config/fish/completions/dotf.fish"

fish --no-execute "$function_file"
fish --no-execute "$completion_file"
if grep -Eq 'desktop\|workstation|desktop workstation|<profile>|<perfil>|one profile' \
	"$function_file" "$completion_file"; then
	exit 1
fi
grep -Fq 'XDG_CONFIG_HOME' "$function_file"
grep -Fq 'dotfiles/repo' "$function_file"
grep -Fq -- "-a host -d 'Manage private host configuration'" "$completion_file"
grep -Fq -- "-a configure -d 'Configure host choices'" "$completion_file"

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p -- "$test_root/config/dotfiles" "$test_root/bin"
printf '%s\n' "$repo_root" >"$test_root/config/dotfiles/repo"

cat >"$test_root/bin/just" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*"
EOF
chmod +x "$test_root/bin/just"

output=$(
	env HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
		PATH="$test_root/bin:$PATH" fish --no-config -c \
		"source '$function_file'; dotf check"
)
[[ "$output" == "--justfile $repo_root/justfile check" ]]

host_output=$(
	env HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
		XDG_STATE_HOME="$test_root/state" PATH="$test_root/bin:$PATH" \
		fish --no-config -c "source '$function_file'; dotf host show --safe-defaults"
)
python3 -c 'import json,sys; assert "hypr-common" in json.loads(sys.stdin.read())["modules"]' <<<"$host_output"

printf '%s\n' 'PASS: dotf usa el registro XDG y comandos sin perfiles'
