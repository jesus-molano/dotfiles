#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
backup_helper="$repo_root/backup/.local/bin/dotfiles-backup"
maintenance_helper="$repo_root/backup/.local/bin/dotfiles-backup-maintenance"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/config/restic" "$test_root/config/dotfiles" \
	"$test_root/home/Documents" "$test_root/home/dev/project/.git/objects" "$test_root/home/.local/bin" \
	"$test_root/home/.local/lib/dotfiles" "$test_root/runtime" "$test_root/snapshots" \
	"$test_root/alternate-checkout/docs"
printf '%s/%s\n' '~' Documents >"$test_root/config/restic/dotfiles.paths"
printf '%s/%s\n' '~' dev >>"$test_root/config/restic/dotfiles.paths"
: >"$test_root/config/restic/dotfiles.excludes"
printf '%s\n' "$test_root/alternate-checkout" >"$test_root/config/dotfiles/repo"
printf '%s\n' '/mnt/backups/restic-desktop' >"$test_root/config/restic/repository"
cp -- "$repo_root/backup/.local/lib/dotfiles/restic-env.sh" \
	"$test_root/home/.local/lib/dotfiles/restic-env.sh"

cat >"$test_root/bin/restic" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command=$1
shift
printf '%s\t%s\n' "$command" "$*" >>"$TEST_RESTIC_LOG"
case "$command" in
backup)
	paths=
	while (($#)); do
		if [[ "$1" == --files-from ]]; then paths=$2; shift 2; continue; fi
		shift
	done
	cp "$paths" "$TEST_PATHS"
	canary=$(grep '/dotfiles-backup/canary.txt$' "$paths")
	id=${TEST_BACKUP_ID:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}
	directory="$TEST_SNAPSHOTS/$RESTIC_HOST/$id"
	mkdir -p "$directory"
	cp "$canary" "$directory/canary.txt"
	printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$directory/time"
	;;
snapshots)
	[[ "$#" == 5 && "$1" == --json && "$2" == --host && "$3" == "$RESTIC_HOST" &&
		"$4" == --tag && "$5" == desktop ]]
	python3 - "$TEST_SNAPSHOTS" <<'PY'
import datetime as dt
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
items = []
for item in root.glob('*/*'):
    if not item.is_dir():
        continue
    items.append({
        'id': item.name,
        'hostname': item.parent.name,
        'time': (item / 'time').read_text(encoding='utf-8').strip(),
        'tags': ['desktop'],
    })
print(json.dumps(items))
PY
	;;
check|forget|prune) ;;
restore)
	verify=$1
	[[ "$verify" == --verify ]]
	snapshot=$2
	shift 2
	target=
	while (($#)); do
		if [[ "$1" == --target ]]; then target=$2; shift 2; continue; fi
		shift
	done
	[[ -n "$target" ]]
	match=$(find "$TEST_SNAPSHOTS" -path "*/$snapshot/canary.txt" -type f -print -quit)
	[[ -n "$match" ]]
	mkdir -p "$target/home/test/.local/state/dotfiles-backup"
	if [[ ${TEST_RESTORE_CORRUPT:-0} == 1 ]]; then
		printf '%s\n' 'canario-restaurado-inválido' >"$target/home/test/.local/state/dotfiles-backup/canary.txt"
	else
		cp "$match" "$target/home/test/.local/state/dotfiles-backup/canary.txt"
	fi
	;;
*) printf 'restic fake inesperado: %s\n' "$command" >&2; exit 2 ;;
esac
EOF
cat >"$test_root/bin/ludusavi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_LUDUSAVI_LOG"
EOF
cat >"$test_root/home/.local/bin/desktop-notify" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$test_root/home/.local/bin/with-secrets" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_WITH_SECRETS_LOG"
RESTIC_PASSWORD=fixture exec "$@"
EOF
chmod +x "$test_root/bin/"* "$test_root/home/.local/bin/"*
: >"$test_root/ludusavi.log"
export TEST_LUDUSAVI_LOG="$test_root/ludusavi.log"

	PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" \
	RESTIC_HOST=desktop-a TEST_WITH_SECRETS_LOG="$test_root/with-secrets.log" \
	TEST_PATHS="$test_root/paths" TEST_RESTIC_LOG="$test_root/restic.log" TEST_SNAPSHOTS="$test_root/snapshots" \
	bash "$backup_helper" >"$test_root/output"
grep -Fxq "env DOTFILES_RESTIC_ENV=1 $backup_helper" "$test_root/with-secrets.log"
grep -Fxq "$test_root/alternate-checkout" "$test_root/paths"
grep -Fxq "$test_root/home/dev" "$test_root/paths"
grep -Fxq "$test_root/config/dotfiles" "$test_root/paths"
if grep -Fq "$test_root/alternate-checkout" "$test_root/output"; then exit 1; fi
grep -Fxq '/mnt/backups/restic-desktop' "$test_root/config/restic/repository"
if grep -Fq '.dotfiles' "$repo_root/backup/.config/restic/dotfiles.paths"; then exit 1; fi
dev_entry=$(printf '%s/%s' '~' dev)
grep -Fxq "$dev_entry" "$repo_root/backup/.config/restic/dotfiles.paths"
if grep -Fq '.git/objects' "$repo_root/backup/.config/restic/dotfiles.excludes"; then exit 1; fi
if grep -Fq 'RESTIC_REPOSITORY=' "$repo_root/backup/.config/systemd/user/restic-backup.service"; then exit 1; fi
if grep -Fq 'RESTIC_REPOSITORY=' "$repo_root/backup/.config/systemd/user/restic-maintenance.service"; then exit 1; fi
canary="$test_root/state/dotfiles-backup/canary.txt"
[[ -f "$canary" && ! -L "$canary" ]]
[[ $(stat -c '%a' "$canary") == 600 ]]
grep -Fxq dotfiles-restic-canary-v2 "$canary"
grep -Eq '^token=[0-9a-f]{64}$' "$canary"
first_token=$(sed -n 's/^token=//p' "$canary")
if grep -Fq "$first_token" "$test_root/output"; then
	printf '%s\n' 'FAIL: el backup imprimió el token privado del canario.' >&2
	exit 1
fi
grep -Fq $'backup\t--tag desktop --files-from ' "$test_root/restic.log"
grep -Fxq "backup --force --no-cloud-sync --path $test_root/state/gaming/ludusavi" \
	"$test_root/ludusavi.log"

# Cada backup debe generar un token distinto. El fake conserva ambos
# snapshots para comprobar que maintenance elige el más nuevo del host local.
first_snapshot="$test_root/snapshots/desktop-a/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ >"$first_snapshot/time"
PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" \
	DOTFILES_RESTIC_ENV=1 RESTIC_PASSWORD=test RESTIC_HOST=desktop-a \
	TEST_BACKUP_ID=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
	TEST_PATHS="$test_root/paths-second" TEST_RESTIC_LOG="$test_root/restic.log" TEST_SNAPSHOTS="$test_root/snapshots" \
	bash "$backup_helper" >"$test_root/output-second"
second_token=$(sed -n 's/^token=//p' "$canary")
[[ "$first_token" != "$second_token" ]]
second_snapshot="$test_root/snapshots/desktop-a/cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
cmp -- "$canary" "$second_snapshot/canary.txt"
if grep -Fq "$second_token" "$test_root/output-second"; then
	printf '%s\n' 'FAIL: el backup imprimió el token privado del canario.' >&2
	exit 1
fi

# Un snapshot más reciente de otro host no puede ganar al desktop actual. El
# fake lista ambos y maintenance debe restaurar el ID exacto del host local.
foreign="$test_root/snapshots/laptop-b/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
mkdir -p "$foreign"
printf '%s\n' 'canario-de-otro-host' >"$foreign/canary.txt"
date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ >"$foreign/time"
PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" \
	DOTFILES_RESTIC_ENV=1 RESTIC_PASSWORD=test RESTIC_HOST=desktop-a \
	TEST_PATHS="$test_root/paths" TEST_RESTIC_LOG="$test_root/restic-maintenance.log" TEST_SNAPSHOTS="$test_root/snapshots" \
	bash "$maintenance_helper" >"$test_root/maintenance.out"
grep -Fq $'snapshots\t--json --host desktop-a --tag desktop' "$test_root/restic-maintenance.log"
grep -Fq $'restore\t--verify cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc --target ' "$test_root/restic-maintenance.log"
grep -Fq $'check\t--read-data-subset=5%' "$test_root/restic-maintenance.log"
grep -Fq $'prune\t' "$test_root/restic-maintenance.log"
[[ $(grep -n $'^check\t' "$test_root/restic-maintenance.log" | cut -d: -f1) -lt $(grep -n $'^restore\t' "$test_root/restic-maintenance.log" | cut -d: -f1) ]]
[[ $(grep -n $'^restore\t' "$test_root/restic-maintenance.log" | cut -d: -f1) -lt $(grep -n $'^prune\t' "$test_root/restic-maintenance.log" | cut -d: -f1) ]]

# Un restore que no reproduce el canario exacto debe impedir prune, aunque el
# check previo haya terminado bien.
: >"$test_root/restic-corrupt.log"
if PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" \
	DOTFILES_RESTIC_ENV=1 RESTIC_PASSWORD=test RESTIC_HOST=desktop-a TEST_RESTORE_CORRUPT=1 \
	TEST_PATHS="$test_root/paths" TEST_RESTIC_LOG="$test_root/restic-corrupt.log" TEST_SNAPSHOTS="$test_root/snapshots" \
	bash "$maintenance_helper" >"$test_root/corrupt.out" 2>&1; then
	printf '%s\n' 'FAIL: maintenance aceptó un canario restaurado distinto.' >&2
	exit 1
fi
grep -Fq $'check\t--read-data-subset=5%' "$test_root/restic-corrupt.log"
grep -Fq $'restore\t--verify cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc --target ' "$test_root/restic-corrupt.log"
if grep -Eq '^prune' "$test_root/restic-corrupt.log"; then
	printf '%s\n' 'FAIL: maintenance ejecutó prune tras un restore inválido.' >&2
	exit 1
fi

# Si el snapshot local está viejo, maintenance aborta antes de cualquier check,
# restore o prune. Un backup fallido deja exactamente esta señal de frescura.
date -u -d '-4 days' +%Y-%m-%dT%H:%M:%SZ >"$first_snapshot/time"
date -u -d '-4 days' +%Y-%m-%dT%H:%M:%SZ >"$second_snapshot/time"
: >"$test_root/restic-stale.log"
if PATH="$test_root/bin:$PATH" HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
	XDG_STATE_HOME="$test_root/state" XDG_RUNTIME_DIR="$test_root/runtime" \
	DOTFILES_RESTIC_ENV=1 RESTIC_PASSWORD=test RESTIC_HOST=desktop-a \
	TEST_PATHS="$test_root/paths" TEST_RESTIC_LOG="$test_root/restic-stale.log" TEST_SNAPSHOTS="$test_root/snapshots" \
	bash "$maintenance_helper" >"$test_root/stale.out" 2>&1; then
	printf '%s\n' 'FAIL: maintenance aceptó un snapshot local obsoleto.' >&2
	exit 1
fi
grep -Fq 'supera el umbral de 72 horas' "$test_root/stale.out"
if grep -Eq '^(check|restore|prune)' "$test_root/restic-stale.log"; then
	printf '%s\n' 'FAIL: maintenance modificó o verificó Restic tras detectar snapshot obsoleto.' >&2
	exit 1
fi
printf '%s\n' 'PASS: backup usa canario privado por intento y maintenance selecciona/restaura el snapshot fresco exacto'
