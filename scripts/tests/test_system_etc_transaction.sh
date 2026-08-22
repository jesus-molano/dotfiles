#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
helper="$repo_root/scripts/system-etc-transaction.sh"
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/source/udev/rules.d" "$test_root/etc/udev/rules.d" \
	"$test_root/config/dotfiles" "$test_root/state"
printf '%s\n' new-first >"$test_root/source/udev/rules.d/10-first.rules"
printf '%s\n' new-second >"$test_root/source/udev/rules.d/20-second.rules"
printf '%s\n' old-first >"$test_root/etc/udev/rules.d/10-first.rules"

cat >"$test_root/bin/pkexec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == /usr/bin/install && "${*: -1}" == *20-second.rules ]]; then
	exit 73
fi
exec "$@"
EOF
chmod +x "$test_root/bin/pkexec"

if PATH="$test_root/bin:$PATH" \
	DOTFILES_SYSTEM_ETC_SOURCE_ROOT="$test_root/source" \
	DOTFILES_SYSTEM_ETC_TARGET_ROOT="$test_root/etc" \
	DOTFILES_SYSTEM_ETC_PKEXEC=pkexec \
	XDG_STATE_HOME="$test_root/state" XDG_CONFIG_HOME="$test_root/config" \
	bash "$helper" --apply udev >/dev/null 2>&1; then
	printf '%s\n' 'El fallo simulado de install debía abortar.' >&2
	exit 1
fi
[[ $(<"$test_root/etc/udev/rules.d/10-first.rules") == old-first ]]
[[ ! -e "$test_root/etc/udev/rules.d/20-second.rules" ]]
backup_root=$(find "$test_root/state/dotfiles/system-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
grep -Fq $'existing\t'"$test_root/etc/udev/rules.d/10-first.rules"$'\t' "$backup_root/journal.tsv"
grep -Fq $'absent\t'"$test_root/etc/udev/rules.d/20-second.rules"$'\t' "$backup_root/journal.tsv"
[[ $(<"$backup_root/preimages$test_root/etc/udev/rules.d/10-first.rules") == old-first ]]

# Un segundo fallo dentro del rollback no debe impedir restaurar los demás
# destinos. El helper registra exactamente qué operación quedó pendiente.
rollback_root="$test_root/rollback-failure"
mkdir -p "$rollback_root/source/udev/rules.d" "$rollback_root/etc/udev/rules.d" \
	"$rollback_root/config" "$rollback_root/state"
printf '%s\n' new-first >"$rollback_root/source/udev/rules.d/10-first.rules"
printf '%s\n' new-second >"$rollback_root/source/udev/rules.d/20-second.rules"
printf '%s\n' new-third >"$rollback_root/source/udev/rules.d/30-third.rules"
printf '%s\n' old-first >"$rollback_root/etc/udev/rules.d/10-first.rules"
cat >"$test_root/bin/pkexec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == /usr/bin/install && "${*: -1}" == *30-third.rules ]]; then
	exit 73
fi
if [[ "$1" == /usr/bin/rm && "${*: -1}" == *20-second.rules ]]; then
	exit 74
fi
exec "$@"
EOF
chmod +x "$test_root/bin/pkexec"
if PATH="$test_root/bin:$PATH" \
	DOTFILES_SYSTEM_ETC_SOURCE_ROOT="$rollback_root/source" \
	DOTFILES_SYSTEM_ETC_TARGET_ROOT="$rollback_root/etc" \
	DOTFILES_SYSTEM_ETC_PKEXEC=pkexec \
	XDG_STATE_HOME="$rollback_root/state" XDG_CONFIG_HOME="$rollback_root/config" \
	bash "$helper" --apply udev >"$rollback_root/output" 2>&1; then
	printf '%s\n' 'El doble fallo simulado debía abortar.' >&2
	exit 1
fi
[[ $(<"$rollback_root/etc/udev/rules.d/10-first.rules") == old-first ]]
[[ $(<"$rollback_root/etc/udev/rules.d/20-second.rules") == new-second ]]
rollback_failure_backup=$(find "$rollback_root/state/dotfiles/system-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
grep -Fqx $'absent\t'"$rollback_root/etc/udev/rules.d/20-second.rules" \
	"$rollback_failure_backup/rollback-incomplete.tsv"
grep -Fq 'Rollback incompleto' "$rollback_root/output"

cat >"$test_root/bin/pkexec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$@"
EOF
chmod +x "$test_root/bin/pkexec"
PATH="$test_root/bin:$PATH" \
DOTFILES_SYSTEM_ETC_SOURCE_ROOT="$test_root/source" \
DOTFILES_SYSTEM_ETC_TARGET_ROOT="$test_root/etc" \
DOTFILES_SYSTEM_ETC_PKEXEC=pkexec \
XDG_STATE_HOME="$test_root/state-success" XDG_CONFIG_HOME="$test_root/config" \
bash "$helper" --apply udev >/dev/null
[[ $(<"$test_root/etc/udev/rules.d/10-first.rules") == new-first ]]
[[ $(<"$test_root/etc/udev/rules.d/20-second.rules") == new-second ]]
[[ -f "$test_root/state-success/dotfiles/last-system-backup" ]]

if DOTFILES_SYSTEM_ETC_TARGET_ROOT="$test_root/etc" XDG_CONFIG_HOME="$test_root/missing-config" \
	bash "$helper" --check systemd >/dev/null 2>&1; then
	printf '%s\n' 'systemd debe requerir configuración local del host.' >&2
	exit 1
fi
printf '%s\n' 'MNT_BACKUPS_UUID=ABCD-1234' 'MNT_BACKUPS_UID=1001' 'MNT_BACKUPS_GID=1002' \
	>"$test_root/config/dotfiles/systemd-mnt-backups.conf"
mkdir -p "$test_root/etc/systemd/system"
sed -e 's/@MNT_BACKUPS_UUID@/ABCD-1234/g' -e 's/@MNT_BACKUPS_UID@/1001/g' -e 's/@MNT_BACKUPS_GID@/1002/g' \
	"$repo_root/system-etc/systemd/system/mnt-backups.mount.template" \
	>"$test_root/etc/systemd/system/mnt-backups.mount"
cp -- "$repo_root/system-etc/systemd/system/mnt-backups.automount" "$test_root/etc/systemd/system/mnt-backups.automount"
DOTFILES_SYSTEM_ETC_TARGET_ROOT="$test_root/etc" XDG_CONFIG_HOME="$test_root/config" \
	bash "$helper" --check systemd | grep -Fqx "= $test_root/etc/systemd/system/mnt-backups.mount"

printf '%s\n' 'PASS: system-etc revierte, registra preimágenes y protege systemd por host'
