#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$repo_root/backup/.local/bin/dotfiles-backup"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/config/restic" "$test_root/config/dotfiles" \
	"$test_root/home/Documents" "$test_root/home/.local/bin" \
	"$test_root/home/.local/lib/dotfiles" "$test_root/runtime" \
	"$test_root/alternate-checkout/docs"
printf '%s/%s\n' '~' Documents >"$test_root/config/restic/dotfiles.paths"
: >"$test_root/config/restic/dotfiles.excludes"
printf '%s\n' "$test_root/alternate-checkout" >"$test_root/config/dotfiles/repo"
printf '%s\n' '/mnt/backups/restic-desktop' >"$test_root/config/restic/repository"
cp -- "$repo_root/backup/.local/lib/dotfiles/restic-env.sh" \
	"$test_root/home/.local/lib/dotfiles/restic-env.sh"

cat >"$test_root/bin/restic" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == backup ]]; then
	while (($#)); do
		if [[ "$1" == --files-from ]]; then cp "$2" "$TEST_PATHS"; fi
		shift
	done
fi
EOF
cat >"$test_root/home/.local/bin/desktop-notify" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$test_root/bin/"* "$test_root/home/.local/bin/desktop-notify"

	PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" \
	DOTFILES_RESTIC_ENV=1 RESTIC_PASSWORD=test TEST_PATHS="$test_root/paths" \
	bash "$helper" >/dev/null
grep -Fxq "$test_root/alternate-checkout" "$test_root/paths"
grep -Fxq '/mnt/backups/restic-desktop' "$test_root/config/restic/repository"
if grep -Fq '.dotfiles' "$repo_root/backup/.config/restic/dotfiles.paths"; then exit 1; fi
if grep -Fq 'RESTIC_REPOSITORY=' "$repo_root/backup/.config/systemd/user/restic-backup.service"; then exit 1; fi
if grep -Fq 'RESTIC_REPOSITORY=' "$repo_root/backup/.config/systemd/user/restic-maintenance.service"; then exit 1; fi
grep -Fq 'restore latest --tag desktop' "$repo_root/backup/.local/bin/dotfiles-backup-maintenance"
printf '%s\n' 'PASS: backup incluye el checkout registrado sin fijar HOME'
