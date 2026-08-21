#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

fixture_repo="$test_root/repo"
fixture_home="$test_root/home"
fixture_state="$test_root/state"
fixture_config="$test_root/config"
mkdir -p "$fixture_repo/scripts/tests/fixtures" "$fixture_home" "$fixture_state" "$fixture_config" "$test_root/bin"
cp -- "$repo_root/install.sh" "$fixture_repo/install.sh"
cp -- "$repo_root/scripts/tests/fixtures/current-host.toml" "$fixture_repo/scripts/tests/fixtures/current-host.toml"
cp -- "$repo_root/scripts/tests/fixtures/laptop-host.toml" "$fixture_repo/scripts/tests/fixtures/laptop-host.toml"

# The old modules model the exact no-folding links that the first profileless
# deployment must remove. The new module also collides with one personal file,
# so rollback has to restore both managed and unmanaged state.
mkdir -p \
	"$fixture_repo/hypr-desktop/.config/hypr/config" \
	"$fixture_repo/hypr-common/.config/hypr/config" \
	"$fixture_repo/qmd/.config/qmd" \
	"$fixture_repo/hypr-host/.config/hypr/config" \
	"$fixture_repo/hypr-desktop/.config/reactive-rgb" \
	"$fixture_repo/gaming/.local/bin" \
	"$fixture_repo/backup/.local/bin"
printf '%s\n' old-hypr >"$fixture_repo/hypr-desktop/.config/hypr/config/legacy.lua"
printf '%s\n' old-monitors >"$fixture_repo/hypr-desktop/.config/hypr/config/monitors.lua"
printf '%s\n' old-inputs >"$fixture_repo/hypr-desktop/.config/hypr/config/user-inputs.lua"
printf '%s\n' old-rgb >"$fixture_repo/hypr-desktop/.config/reactive-rgb/config.conf"
printf '%s\n' old-game >"$fixture_repo/gaming/.local/bin/game-run"
printf '%s\n' old-backup >"$fixture_repo/backup/.local/bin/desktop-backup"
printf '%s\n' old-qmd >"$fixture_repo/qmd/.config/qmd/index.yml"
printf '%s\n' common-before >"$fixture_repo/hypr-common/.config/hypr/config/common.lua"
printf '%s\n' new-host >"$fixture_repo/hypr-host/.config/hypr/config/host.lua"
printf '%s\n' new-managed >"$fixture_repo/hypr-host/.config/personal.conf"

git -C "$fixture_repo" init -q
git -C "$fixture_repo" add .
git -C "$fixture_repo" -c user.name=Test -c user.email=test.invalid@example.invalid commit -qm fixture

stow --no-folding --dir "$fixture_repo" --target "$fixture_home" hypr-desktop gaming backup qmd
mkdir -p "$fixture_home/.config"
printf '%s\n' personal >"$fixture_home/.config/personal.conf"

# Resolver la equivalencia legacy en modo de inspección no debe crear
# host.toml. El apply explícito conserva después la selección exacta.
readonly_runner="$test_root/read-only.sh"
cat >"$readonly_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
fixture=$(legacy_fixture_for_host)
[[ "$fixture" == "$FIXTURE_REPO/scripts/tests/fixtures/current-host.toml" ]]
[[ ! -e "$XDG_CONFIG_HOME/dotfiles/host.toml" ]]
EOF
chmod +x "$readonly_runner"
HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" "$readonly_runner"

cat >"$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
'--user is-enabled reactive-rgb.service' | '--user is-active reactive-rgb.service') exit 1 ;;
*) exit 0 ;;
esac
EOF
chmod +x "$test_root/bin/systemctl"

plan="$test_root/plan.json"
printf '%s\n' \
	'{"schema":1,"repo":"fixture","modules":["hypr-host"],"bundles":["productivity-extra"],"package_scopes":["base","bundle:productivity-extra"]}' \
	>"$plan"
mkdir -p "$fixture_state/dotfiles/staged/qmd"
printf '%s\n' generated-qmd >"$fixture_state/dotfiles/staged/qmd/index.yml"
mkdir -p "$fixture_state/dotfiles/generated/hypr/config" "$fixture_state/dotfiles/plans"
printf '%s\n' old-derived >"$fixture_state/dotfiles/generated/hypr/config/host.lua"
printf '%s\n' old-plan >"$fixture_state/dotfiles/plans/resolved.json"

runner="$test_root/run.sh"
cat >"$runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
PACKAGE_SCOPES=(base bundle:productivity-extra)
BACKUP_DIR="$STATE_DIR/backups/test"
seed_exact_legacy_host "$XDG_CONFIG_HOME/dotfiles/host.toml"
generate_derived_state() {
    mkdir -p "$STATE_DIR/generated/hypr/config" "$STATE_DIR/plans"
    printf '%s\n' new-derived >"$STATE_DIR/generated/hypr/config/host.lua"
    printf '%s\n' new-plan >"$STATE_DIR/plans/resolved.json"
    record_derived_state
}
validate_deployed_config() { return 0; }
configure_user_services() { return 1; }
apply_dotfiles_transaction
EOF
chmod +x "$runner"

set +e
PATH="$test_root/bin:$PATH" \
	HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$runner" >"$test_root/run.log" 2>&1
code=$?
set -e
[[ $code -ne 0 ]] || {
	printf '%s\n' 'FAIL: el instalador aceptó un fallo posterior a Stow.' >&2
	exit 1
}

migration=$(<"$fixture_state/dotfiles/last-migration")
[[ "$migration" == "$fixture_state/dotfiles/migrations/"* ]]
[[ $(<"$migration/status") == rolled-back ]]
grep -Fq '"gaming-core"' "$fixture_config/dotfiles/host.toml"
grep -Fxq hypr-desktop "$migration/legacy-modules"
grep -Fxq qmd "$migration/legacy-modules"
grep -Fq $'.config/hypr/config/legacy.lua\t' "$migration/symlinks.tsv"
grep -Fq $'.config/qmd/index.yml\t' "$migration/symlinks.tsv"
(cd "$migration" && sha256sum -c SHA256SUMS >/dev/null)

# Rollback no depends on old modules remaining in the checkout. The restored
# links intentionally point into the private transaction snapshot.
legacy_target=$(readlink -f "$fixture_home/.config/hypr/config/legacy.lua")
qmd_target=$(readlink -f "$fixture_home/.config/qmd/index.yml")
[[ "$legacy_target" == "$migration/modules/hypr-desktop/"* ]]
[[ "$qmd_target" == "$migration/modules/qmd/"* ]]
[[ $(<"$fixture_home/.config/hypr/config/legacy.lua") == old-hypr ]]
[[ $(<"$fixture_home/.config/qmd/index.yml") == old-qmd ]]
[[ $(<"$fixture_home/.config/personal.conf") == personal ]]
[[ ! -e "$fixture_home/.config/hypr/config/host.lua" ]]
[[ ! -e "$fixture_config/qmd/index.yml" ]]
[[ $(<"$fixture_state/dotfiles/generated/hypr/config/host.lua") == old-derived ]]
[[ $(<"$fixture_state/dotfiles/plans/resolved.json") == old-plan ]]
rm -f -- "$fixture_home/.config/personal.conf"

# A second apply after a rollback must treat the restored snapshot links as the
# active composition, even though they no longer point at the checkout.
printf '%s\n' "$migration" >"$fixture_state/dotfiles/last-migration"
restored_runner="$test_root/restored-active.sh"
cat >"$restored_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/restored-active"
begin_migration
grep -Fq '.config/hypr/config/legacy.lua' "$MIGRATION_DIR/previous-applied-links.tsv"
deploy_dotfiles
[[ ! -L "$HOME/.config/hypr/config/legacy.lua" ]]
rollback_migration
[[ -L "$HOME/.config/hypr/config/legacy.lua" ]]
rollback_migration
EOF
chmod +x "$restored_runner"
PATH="$test_root/bin:$PATH" HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$restored_runner"

# If resolve --write fails after writing a prefix, its exact derived state is
# captured and the pre-transaction snapshot is restored.
partial_derived_runner="$test_root/partial-derived.sh"
cat >"$partial_derived_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/partial-derived"
python3() {
    mkdir -p "$STATE_DIR/generated/hypr/config" "$STATE_DIR/plans"
    printf '%s\n' partial-derived >"$STATE_DIR/generated/hypr/config/host.lua"
    printf '%s\n' partial-plan >"$STATE_DIR/plans/resolved.json"
    return 1
}
begin_migration
if generate_derived_state; then exit 9; fi
[[ -s "$MIGRATION_DIR/derived-installed.tsv" ]]
rollback_migration
[[ $(<"$STATE_DIR/generated/hypr/config/host.lua") == old-derived ]]
[[ $(<"$STATE_DIR/plans/resolved.json") == old-plan ]]
EOF
chmod +x "$partial_derived_runner"
HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$partial_derived_runner"

# The derived-state guard refuses to overwrite a change made after a failed
# generation attempt.
derived_guard_runner="$test_root/derived-guard.sh"
cat >"$derived_guard_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/derived-guard"
python3() {
    printf '%s\n' partial >"$STATE_DIR/generated/hypr/config/host.lua"
    return 1
}
begin_migration
if generate_derived_state; then exit 9; fi
printf '%s\n' user-change >"$STATE_DIR/generated/hypr/config/host.lua"
if rollback_migration; then exit 9; fi
[[ $(<"$STATE_DIR/generated/hypr/config/host.lua") == user-change ]]
EOF
chmod +x "$derived_guard_runner"
HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$derived_guard_runner"

# Deselecting optional bundles removes only files whose recorded hashes still
# match, and a later failure restores the exact generated copies.
for key in qmd rgb restic; do
	case "$key" in
	qmd) target="$fixture_config/qmd/index.yml" ;;
	rgb) target="$fixture_config/reactive-rgb/config.conf" ;;
	restic) target="$fixture_config/restic/repository" ;;
	esac
	mkdir -p "$(dirname "$target")"
	printf '%s\n' "managed-$key" >"$target"
done
generated_previous="$fixture_state/dotfiles/migrations/deployment-generated-previous"
mkdir -p "$generated_previous"
printf '%s\n' applied >"$generated_previous/status"
: >"$generated_previous/applied-links.tsv"
for key in qmd rgb restic; do
	case "$key" in
	qmd) target="$fixture_config/qmd/index.yml" ;;
	rgb) target="$fixture_config/reactive-rgb/config.conf" ;;
	restic) target="$fixture_config/restic/repository" ;;
	esac
	printf '%s\t%s\n' "$key" "$(sha256sum "$target" | cut -d' ' -f1)" >>"$generated_previous/generated-installed.tsv"
done
printf '%s\n' "$generated_previous" >"$fixture_state/dotfiles/last-migration"
empty_plan="$test_root/empty-plan.json"
printf '%s\n' '{"schema":1,"repo":"fixture","modules":[],"bundles":[],"package_scopes":["base"]}' >"$empty_plan"
deselected_runner="$test_root/deselected-generated.sh"
cat >"$deselected_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/deselected"
begin_migration
remove_deselected_generated_targets
[[ ! -e "$XDG_CONFIG_HOME/qmd/index.yml" ]]
[[ ! -e "$XDG_CONFIG_HOME/reactive-rgb/config.conf" ]]
[[ ! -e "$XDG_CONFIG_HOME/restic/repository" ]]
rollback_migration
[[ $(<"$XDG_CONFIG_HOME/qmd/index.yml") == managed-qmd ]]
[[ $(<"$XDG_CONFIG_HOME/reactive-rgb/config.conf") == managed-rgb ]]
[[ $(<"$XDG_CONFIG_HOME/restic/repository") == managed-restic ]]
[[ -s "$MIGRATION_DIR/restored-active-generated.tsv" ]]
EOF
chmod +x "$deselected_runner"
HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$empty_plan" "$deselected_runner"

# A rollback of a deselection carries the restored generated manifest forward;
# the retry can then retire all three targets again.
generated_retry_runner="$test_root/deselected-retry.sh"
cat >"$generated_retry_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/deselected-retry"
begin_migration
grep -Fxq qmd$'\t'"$(sha256sum "$XDG_CONFIG_HOME/qmd/index.yml" | cut -d' ' -f1)" "$MIGRATION_DIR/previous-generated-installed.tsv"
grep -Fxq rgb$'\t'"$(sha256sum "$XDG_CONFIG_HOME/reactive-rgb/config.conf" | cut -d' ' -f1)" "$MIGRATION_DIR/previous-generated-installed.tsv"
grep -Fxq restic$'\t'"$(sha256sum "$XDG_CONFIG_HOME/restic/repository" | cut -d' ' -f1)" "$MIGRATION_DIR/previous-generated-installed.tsv"
remove_deselected_generated_targets
[[ ! -e "$XDG_CONFIG_HOME/qmd/index.yml" && ! -e "$XDG_CONFIG_HOME/reactive-rgb/config.conf" && ! -e "$XDG_CONFIG_HOME/restic/repository" ]]
EOF
chmod +x "$generated_retry_runner"
HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$empty_plan" "$generated_retry_runner"

# A modified generated file is never removed merely because its bundle was
# deselected.
printf '%s\n' user-edit >"$fixture_config/qmd/index.yml"
printf '%s\n' "$generated_previous" >"$fixture_state/dotfiles/last-migration"
modified_runner="$test_root/modified-generated.sh"
cat >"$modified_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/modified"
begin_migration
if remove_deselected_generated_targets; then exit 9; fi
[[ $(<"$XDG_CONFIG_HOME/qmd/index.yml") == user-edit ]]
EOF
chmod +x "$modified_runner"
HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$empty_plan" "$modified_runner"

# A later deployment must remove only links from the last *applied* plan when
# an optional bundle disappears, then restore that exact composition on error.
previous="$fixture_state/dotfiles/migrations/deployment-previous"
mkdir -p "$previous"
printf '%s\n' applied >"$previous/status"
printf '.config/old-bundle.conf\t/old/optional-bundle.conf\n' >"$previous/applied-links.tsv"
mkdir -p "$previous/applied-referents/.config"
printf '%s\n' old-optional >"$previous/applied-referents/.config/old-bundle.conf"
printf '.config/old-bundle.conf\t%s\n' "$previous/applied-referents/.config/old-bundle.conf" >"$previous/applied-snapshot-links.tsv"
ln -s /old/optional-bundle.conf "$fixture_home/.config/old-bundle.conf"
printf '%s\n' "$previous" >"$fixture_state/dotfiles/last-migration"

transition_runner="$test_root/transition.sh"
cat >"$transition_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/transition"
begin_migration
deploy_dotfiles
[[ ! -e "$HOME/.config/old-bundle.conf" && ! -L "$HOME/.config/old-bundle.conf" ]]
[[ -L "$HOME/.config/hypr/config/host.lua" ]]
rollback_migration
[[ -L "$HOME/.config/old-bundle.conf" ]]
[[ $(<"$HOME/.config/old-bundle.conf") == old-optional ]]
EOF
chmod +x "$transition_runner"
PATH="$test_root/bin:$PATH" HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$transition_runner"

# GNU Stow can fail after creating a subset of links. Those links must be
# recorded before returning so the transaction can remove them safely.
partial_runner="$test_root/partial-stow.sh"
cat >"$partial_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/partial"
stow() {
    [[ " $* " == *" --simulate "* ]] && return 0
    mkdir -p "$HOME/.config/hypr/config"
    expected=$(awk -F $'\t' '$1 == ".config/hypr/config/host.lua" { print $2; exit }' "$MIGRATION_DIR/stow-intent.tsv")
    ln -s "$expected" "$HOME/.config/hypr/config/host.lua"
    return 1
}
begin_migration
if deploy_dotfiles; then
    exit 9
fi
grep -Fq '.config/hypr/config/host.lua' "$MIGRATION_DIR/applied-links.tsv"
rollback_migration
[[ ! -L "$HOME/.config/hypr/config/host.lua" ]]
EOF
chmod +x "$partial_runner"
HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$fixture_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$partial_runner"

# A symlink injected after the durable pre-Stow checkpoint is not ours.  The
# automatic rollback must stop intact instead of deleting that race target.
race_home="$test_root/race-home"
race_state="$test_root/race-state"
race_config="$test_root/race-config"
mkdir -p "$race_home" "$race_state" "$race_config"
race_runner="$test_root/stow-race.sh"
cat >"$race_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/stow-race"
stow() {
    [[ " $* " == *" --simulate "* ]] && return 0
    mkdir -p "$HOME/.config/hypr/config"
    ln -s /foreign/race "$HOME/.config/hypr/config/host.lua"
    return 1
}
begin_migration
if deploy_dotfiles; then exit 9; fi
[[ -f "$MIGRATION_DIR/stow-checkpoint" ]]
(cd "$MIGRATION_DIR" && sha256sum -c SHA256SUMS >/dev/null)
if rollback_migration; then exit 9; fi
[[ -L "$HOME/.config/hypr/config/host.lua" ]]
[[ $(readlink "$HOME/.config/hypr/config/host.lua") == /foreign/race ]]
[[ $(<"$MIGRATION_DIR/status") == rollback-incomplete ]]
EOF
chmod +x "$race_runner"
HOME="$race_home" XDG_CONFIG_HOME="$race_config" XDG_STATE_HOME="$race_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$race_runner"

# The checkpoint itself, not a post-Stow manifest, recovers an interrupted
# Stow.  Delete one applied-links row to model an older/partial journal and
# resume from a separate process after the exact new symlink exists.
checkpoint_home="$test_root/checkpoint-home"
checkpoint_state="$test_root/checkpoint-state"
checkpoint_config="$test_root/checkpoint-config"
mkdir -p "$checkpoint_home" "$checkpoint_state" "$checkpoint_config"
checkpoint_writer="$test_root/checkpoint-writer.sh"
cat >"$checkpoint_writer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/checkpoint"
begin_migration
prepare_stow_checkpoint
expected=$(awk -F $'\t' '$1 == ".config/hypr/config/host.lua" { print $2; exit }' "$MIGRATION_DIR/stow-intent.tsv")
mkdir -p "$HOME/.config/hypr/config"
ln -s "$expected" "$HOME/.config/hypr/config/host.lua"
awk 'NR == 1' "$MIGRATION_DIR/applied-links.tsv" >"$MIGRATION_DIR/applied-links.partial"
mv -- "$MIGRATION_DIR/applied-links.partial" "$MIGRATION_DIR/applied-links.tsv"
persist_migration_checkpoint
(cd "$MIGRATION_DIR" && sha256sum -c SHA256SUMS >/dev/null)
EOF
chmod +x "$checkpoint_writer"
checkpoint_recovery="$test_root/checkpoint-recovery.sh"
cat >"$checkpoint_recovery" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
MIGRATION_DIR=$(<"$STATE_DIR/last-migration")
rollback_migration
[[ ! -e "$HOME/.config/hypr/config/host.lua" && ! -L "$HOME/.config/hypr/config/host.lua" ]]
[[ $(<"$MIGRATION_DIR/status") == rolled-back ]]
EOF
chmod +x "$checkpoint_recovery"
HOME="$checkpoint_home" XDG_CONFIG_HOME="$checkpoint_config" XDG_STATE_HOME="$checkpoint_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$checkpoint_writer"
HOME="$checkpoint_home" XDG_CONFIG_HOME="$checkpoint_config" XDG_STATE_HOME="$checkpoint_state" \
	FIXTURE_REPO="$fixture_repo" "$checkpoint_recovery"

# A checkpoint preparation can fail after it has listed a pre-existing common
# link but before it writes stow-checkpoint. The durable format marker means
# Stow itself never ran, so rollback must leave that partial scratch manifest
# (and the common link) untouched rather than taking the legacy fallback.
precheckpoint_home="$test_root/precheckpoint-home"
precheckpoint_state="$test_root/precheckpoint-state"
precheckpoint_config="$test_root/precheckpoint-config"
mkdir -p "$precheckpoint_home" "$precheckpoint_state" "$precheckpoint_config"
stow --no-folding --dir "$fixture_repo" --target "$precheckpoint_home" hypr-common
precheckpoint_plan="$test_root/precheckpoint-plan.json"
printf '%s\n' '{"schema":1,"repo":"fixture","modules":["hypr-common","hypr-host"],"bundles":[],"package_scopes":["base"]}' >"$precheckpoint_plan"
precheckpoint_writer="$test_root/precheckpoint-writer.sh"
cat >"$precheckpoint_writer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-common hypr-host)
BACKUP_DIR="$STATE_DIR/backups/precheckpoint"
begin_migration
grep -Eq '^[0-9a-f]{64}  ./stow-checkpoint-format$' "$MIGRATION_DIR/SHA256SUMS"
(cd "$MIGRATION_DIR" && sha256sum -c SHA256SUMS >/dev/null)
# common.lua is recorded first. host.lua is an unrelated symlink, which makes
# checkpoint preparation abort before stow-checkpoint and before real Stow.
ln -s /foreign/before-checkpoint "$HOME/.config/hypr/config/host.lua"
prepare_stow_checkpoint
EOF
chmod +x "$precheckpoint_writer"
set +e
HOME="$precheckpoint_home" XDG_CONFIG_HOME="$precheckpoint_config" XDG_STATE_HOME="$precheckpoint_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$precheckpoint_plan" "$precheckpoint_writer" >"$test_root/precheckpoint.log" 2>&1
precheckpoint_code=$?
set -e
[[ $precheckpoint_code -ne 0 ]]
precheckpoint_migration=$(<"$precheckpoint_state/dotfiles/last-migration")
[[ $(<"$precheckpoint_migration/stow-checkpoint-format") == v1 ]]
[[ ! -e "$precheckpoint_migration/stow-checkpoint" && ! -L "$precheckpoint_migration/stow-checkpoint" ]]
grep -Fq '.config/hypr/config/common.lua' "$precheckpoint_migration/applied-links.tsv"
precheckpoint_recovery="$test_root/precheckpoint-recovery.sh"
cat >"$precheckpoint_recovery" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
MIGRATION_DIR=$(<"$STATE_DIR/last-migration")
rollback_migration
[[ -L "$HOME/.config/hypr/config/common.lua" ]]
[[ $(<"$HOME/.config/hypr/config/common.lua") == common-before ]]
[[ -L "$HOME/.config/hypr/config/host.lua" ]]
[[ $(readlink "$HOME/.config/hypr/config/host.lua") == /foreign/before-checkpoint ]]
[[ ! -s "$MIGRATION_DIR/restored-active-links.tsv" ]]
[[ $(<"$MIGRATION_DIR/status") == rolled-back ]]
EOF
chmod +x "$precheckpoint_recovery"
HOME="$precheckpoint_home" XDG_CONFIG_HOME="$precheckpoint_config" XDG_STATE_HOME="$precheckpoint_state" \
	FIXTURE_REPO="$fixture_repo" "$precheckpoint_recovery"

# A symlink that appears only after the durable checkpoint is not part of its
# pre-state. The later simulation must fail, rollback must preserve it without
# publishing it as active, and the next apply must be blocked rather than
# deleting the foreign link from a promoted manifest.
postcheckpoint_home="$test_root/postcheckpoint-home"
postcheckpoint_state="$test_root/postcheckpoint-state"
postcheckpoint_config="$test_root/postcheckpoint-config"
mkdir -p "$postcheckpoint_home" "$postcheckpoint_state" "$postcheckpoint_config"
postcheckpoint_plan="$test_root/postcheckpoint-plan.json"
printf '%s\n' '{"schema":1,"repo":"fixture","modules":["hypr-host"],"bundles":[],"package_scopes":["base"]}' >"$postcheckpoint_plan"
postcheckpoint_runner="$test_root/postcheckpoint-race.sh"
cat >"$postcheckpoint_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/postcheckpoint"
stow() {
    if [[ " $* " == *" --simulate "* && -z "${foreign_injected+x}" ]]; then
        foreign_injected=1
        mkdir -p "$HOME/.config/hypr/config"
        ln -s /foreign/after-checkpoint "$HOME/.config/hypr/config/host.lua"
    fi
    command stow "$@"
}
begin_migration
if deploy_dotfiles; then exit 9; fi
[[ -f "$MIGRATION_DIR/stow-checkpoint" ]]
[[ -L "$HOME/.config/hypr/config/host.lua" ]]
[[ $(readlink "$HOME/.config/hypr/config/host.lua") == /foreign/after-checkpoint ]]
if rollback_migration; then exit 9; fi
[[ $(<"$MIGRATION_DIR/status") == rollback-incomplete ]]
[[ ! -e "$MIGRATION_DIR/restored-active-links.tsv" && ! -L "$MIGRATION_DIR/restored-active-links.tsv" ]]
[[ $(readlink "$HOME/.config/hypr/config/host.lua") == /foreign/after-checkpoint ]]
# Second apply: the incomplete rollback gate must stop before it can claim or
# remove the injected link.
if ( begin_migration ); then exit 9; fi
[[ $(readlink "$HOME/.config/hypr/config/host.lua") == /foreign/after-checkpoint ]]
EOF
chmod +x "$postcheckpoint_runner"
HOME="$postcheckpoint_home" XDG_CONFIG_HOME="$postcheckpoint_config" XDG_STATE_HOME="$postcheckpoint_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$postcheckpoint_plan" "$postcheckpoint_runner"

# Migrations recorded before the checkpoint format marker retain the guarded
# applied-links fallback so old completed deployments remain removable.
legacy_checkpoint_home="$test_root/legacy-checkpoint-home"
legacy_checkpoint_state="$test_root/legacy-checkpoint-state"
mkdir -p "$legacy_checkpoint_home" "$legacy_checkpoint_state"
legacy_checkpoint_runner="$test_root/legacy-checkpoint.sh"
cat >"$legacy_checkpoint_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/legacy-checkpoint"
begin_migration
rm -- "$MIGRATION_DIR/stow-checkpoint-format"
mkdir -p "$HOME/.config"
ln -s /old/managed.conf "$HOME/.config/managed.conf"
printf '.config/managed.conf\t/old/managed.conf\n' >"$MIGRATION_DIR/applied-links.tsv"
rollback_migration
[[ ! -e "$HOME/.config/managed.conf" && ! -L "$HOME/.config/managed.conf" ]]
[[ $(<"$MIGRATION_DIR/status") == rolled-back ]]
EOF
chmod +x "$legacy_checkpoint_runner"
HOME="$legacy_checkpoint_home" XDG_STATE_HOME="$legacy_checkpoint_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$empty_plan" "$legacy_checkpoint_runner"

# A common link can predate the first profileless migration.  It remains live
# after a later failure, is recorded as active, and has a private snapshot for
# the next transition.
common_home="$test_root/common-home"
common_state="$test_root/common-state"
common_config="$test_root/common-config"
mkdir -p "$common_home" "$common_state" "$common_config"
stow --no-folding --dir "$fixture_repo" --target "$common_home" hypr-common
common_plan="$test_root/common-plan.json"
printf '%s\n' '{"schema":1,"repo":"fixture","modules":["hypr-common","hypr-host"],"bundles":[],"package_scopes":["base"]}' >"$common_plan"
common_runner="$test_root/common-first-migration.sh"
cat >"$common_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-common hypr-host)
BACKUP_DIR="$STATE_DIR/backups/common-first"
begin_migration
deploy_dotfiles
rollback_migration
[[ -L "$HOME/.config/hypr/config/common.lua" ]]
[[ $(<"$HOME/.config/hypr/config/common.lua") == common-before ]]
[[ ! -e "$HOME/.config/hypr/config/host.lua" && ! -L "$HOME/.config/hypr/config/host.lua" ]]
grep -Fq '.config/hypr/config/common.lua' "$MIGRATION_DIR/restored-active-links.tsv"
grep -Fq '.config/hypr/config/common.lua' "$MIGRATION_DIR/restored-snapshot-links.tsv"
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/common-next"
begin_migration
grep -Fq '.config/hypr/config/common.lua' "$MIGRATION_DIR/previous-applied-links.tsv"
EOF
chmod +x "$common_runner"
PATH="$test_root/bin:$PATH" HOME="$common_home" XDG_CONFIG_HOME="$common_config" XDG_STATE_HOME="$common_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$common_plan" "$common_runner"

# The generated write-ahead journals also tolerate an interruption before mv
# or rm: the old file is recognised as the recorded preimage and is retained.
generated_journal_home="$test_root/generated-journal-home"
generated_journal_state="$test_root/generated-journal-state"
generated_journal_config="$test_root/generated-journal-config"
mkdir -p "$generated_journal_home" "$generated_journal_state" "$generated_journal_config/qmd" \
	"$generated_journal_state/dotfiles/staged/qmd"
printf '%s\n' old-journal-qmd >"$generated_journal_config/qmd/index.yml"
printf '%s\n' new-journal-qmd >"$generated_journal_state/dotfiles/staged/qmd/index.yml"
generated_journal_runner="$test_root/generated-journal.sh"
cat >"$generated_journal_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/generated-journal"
begin_migration
mv() {
    target=${!#}
    [[ "$target" == "$XDG_CONFIG_HOME/qmd/index.yml" ]] && return 1
    command mv "$@"
}
if install_staged_file qmd "$STATE_DIR/staged/qmd/index.yml"; then exit 9; fi
grep -Eq $'^qmd\t[0-9a-f]{64}$' "$MIGRATION_DIR/generated-installed.tsv"
(cd "$MIGRATION_DIR" && sha256sum -c SHA256SUMS >/dev/null)
rollback_migration
[[ $(<"$XDG_CONFIG_HOME/qmd/index.yml") == old-journal-qmd ]]
EOF
chmod +x "$generated_journal_runner"
HOME="$generated_journal_home" XDG_CONFIG_HOME="$generated_journal_config" XDG_STATE_HOME="$generated_journal_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$generated_journal_runner"

# Likewise, a deselection journal written before rm preserves the existing
# generated bytes when the removal command is interrupted before unlinking.
generated_remove_home="$test_root/generated-remove-home"
generated_remove_state="$test_root/generated-remove-state"
generated_remove_config="$test_root/generated-remove-config"
mkdir -p "$generated_remove_home" "$generated_remove_state" "$generated_remove_config/qmd"
printf '%s\n' old-remove-qmd >"$generated_remove_config/qmd/index.yml"
generated_remove_previous="$generated_remove_state/dotfiles/migrations/deployment-generated-remove-previous"
mkdir -p "$generated_remove_previous"
printf '%s\n' applied >"$generated_remove_previous/status"
printf '%s\t%s\n' qmd "$(sha256sum "$generated_remove_config/qmd/index.yml" | cut -d' ' -f1)" >"$generated_remove_previous/generated-installed.tsv"
printf '%s\n' "$generated_remove_previous" >"$generated_remove_state/dotfiles/last-migration"
generated_remove_runner="$test_root/generated-remove-journal.sh"
cat >"$generated_remove_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/generated-remove-journal"
begin_migration
rm() {
    [[ "$*" == *"$XDG_CONFIG_HOME/qmd/index.yml"* ]] && return 1
    command rm "$@"
}
if remove_deselected_generated_targets; then exit 9; fi
grep -Eq $'^qmd\t[0-9a-f]{64}$' "$MIGRATION_DIR/generated-removed.tsv"
(cd "$MIGRATION_DIR" && sha256sum -c SHA256SUMS >/dev/null)
rollback_migration
[[ $(<"$XDG_CONFIG_HOME/qmd/index.yml") == old-remove-qmd ]]
EOF
chmod +x "$generated_remove_runner"
HOME="$generated_remove_home" XDG_CONFIG_HOME="$generated_remove_config" XDG_STATE_HOME="$generated_remove_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$empty_plan" "$generated_remove_runner"

# A broken or overlapping private snapshot is rejected before rollback removes
# even one current link.  This is the fallback gate for an incomplete state.
rollback_guard_home="$test_root/rollback-guard-home"
rollback_guard_state="$test_root/rollback-guard-state"
mkdir -p "$rollback_guard_home" "$rollback_guard_state"
rollback_guard_runner="$test_root/rollback-guard.sh"
cat >"$rollback_guard_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/rollback-guard"
begin_migration
mkdir -p "$HOME/.config"
ln -s /current/source "$HOME/.config/current.conf"
printf '.config/current.conf\t/current/source\n' >"$MIGRATION_DIR/applied-links.tsv"
printf '.config/old.conf\t%s\n' "$MIGRATION_DIR/missing/old.conf" >"$MIGRATION_DIR/previous-restore-links.tsv"
printf '%s\n' yes >"$MIGRATION_DIR/previous-links-removed"
if rollback_migration; then exit 9; fi
[[ -L "$HOME/.config/current.conf" ]]
[[ $(<"$MIGRATION_DIR/status") == rollback-incomplete ]]
if ( begin_migration ); then exit 9; fi
EOF
chmod +x "$rollback_guard_runner"
HOME="$rollback_guard_home" XDG_STATE_HOME="$rollback_guard_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$rollback_guard_runner"

rollback_overlap_home="$test_root/rollback-overlap-home"
rollback_overlap_state="$test_root/rollback-overlap-state"
mkdir -p "$rollback_overlap_home" "$rollback_overlap_state"
rollback_overlap_runner="$test_root/rollback-overlap.sh"
cat >"$rollback_overlap_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/rollback-overlap"
begin_migration
mkdir -p "$HOME/.config" "$MIGRATION_DIR/snapshots"
ln -s /current/source-two "$HOME/.config/current-two.conf"
printf '.config/current-two.conf\t/current/source-two\n' >"$MIGRATION_DIR/applied-links.tsv"
printf one >"$MIGRATION_DIR/snapshots/one"
printf two >"$MIGRATION_DIR/snapshots/two"
printf '.config/duplicate.conf\t%s\n' "$MIGRATION_DIR/snapshots/one" >"$MIGRATION_DIR/previous-restore-links.tsv"
printf '.config/duplicate.conf\t%s\n' "$MIGRATION_DIR/snapshots/two" >"$MIGRATION_DIR/legacy-links.tsv"
printf '%s\n' yes >"$MIGRATION_DIR/previous-links-removed"
printf '%s\n' yes >"$MIGRATION_DIR/legacy-links-removed"
if rollback_migration; then exit 9; fi
[[ -L "$HOME/.config/current-two.conf" ]]
EOF
chmod +x "$rollback_overlap_runner"
HOME="$rollback_overlap_home" XDG_STATE_HOME="$rollback_overlap_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$rollback_overlap_runner"

# A failed legacy withdrawal leaves legacy links live.  The next transaction
# must classify those links as legacy again, rather than removing them once as
# a restored profileless manifest and a second time as legacy.
legacy_retry_home="$test_root/legacy-retry-home"
legacy_retry_state="$test_root/legacy-retry-state"
legacy_retry_config="$test_root/legacy-retry-config"
mkdir -p "$legacy_retry_home" "$legacy_retry_state" "$legacy_retry_config"
stow --no-folding --dir "$fixture_repo" --target "$legacy_retry_home" hypr-desktop gaming qmd
legacy_retry_runner="$test_root/legacy-retry.sh"
cat >"$legacy_retry_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/legacy-retry-first"
begin_migration
rm -- "$HOME/.config/hypr/config/legacy.lua"
ln -s /user/changed.lua "$HOME/.config/hypr/config/legacy.lua"
if ( deploy_dotfiles ); then exit 9; fi
[[ -L "$HOME/.config/hypr/config/monitors.lua" ]]
rollback_migration
[[ $(<"$MIGRATION_DIR/status") == rolled-back ]]
rm -- "$HOME/.config/hypr/config/legacy.lua"
ln -s "$DOTFILES_DIR/hypr-desktop/.config/hypr/config/legacy.lua" "$HOME/.config/hypr/config/legacy.lua"
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/legacy-retry-second"
begin_migration
if grep -Fq '.config/hypr/config/monitors.lua' "$MIGRATION_DIR/previous-applied-links.tsv"; then exit 9; fi
deploy_dotfiles
[[ -L "$HOME/.config/hypr/config/host.lua" ]]
EOF
chmod +x "$legacy_retry_runner"
PATH="$test_root/bin:$PATH" HOME="$legacy_retry_home" XDG_CONFIG_HOME="$legacy_retry_config" XDG_STATE_HOME="$legacy_retry_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$legacy_retry_runner"

# Previous profileless links have separate live and snapshot manifests. A
# changed or deleted checkout source cannot change what rollback restores.
snapshot_home="$test_root/snapshot-home"
snapshot_state="$test_root/snapshot-state"
snapshot_config="$test_root/snapshot-config"
mkdir -p "$snapshot_home" "$snapshot_state" "$snapshot_config"
snapshot_runner="$test_root/applied-snapshot.sh"
cat >"$snapshot_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=(hypr-host)
BACKUP_DIR="$STATE_DIR/backups/snapshot-first"
begin_migration
deploy_dotfiles
printf '%s\n' applied >"$MIGRATION_DIR/status"
write_migration_checksums
first="$MIGRATION_DIR"
printf '%s\n' "$first" >"$STATE_DIR/last-migration"
printf '%s\n' checkout-changed >"$DOTFILES_DIR/hypr-host/.config/hypr/config/host.lua"
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/snapshot-second"
begin_migration
rm -f -- "$DOTFILES_DIR/hypr-host/.config/hypr/config/host.lua"
remove_link_manifest "$MIGRATION_DIR/previous-applied-links.tsv"
printf '%s\n' yes >"$MIGRATION_DIR/previous-links-removed"
rollback_migration
[[ $(<"$HOME/.config/hypr/config/host.lua") == new-host ]]
EOF
chmod +x "$snapshot_runner"
HOME="$snapshot_home" XDG_CONFIG_HOME="$snapshot_config" XDG_STATE_HOME="$snapshot_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$plan" "$snapshot_runner"

# Legacy removal validates every recorded link before removing any of them.
legacy_home="$test_root/legacy-conflict-home"
legacy_state="$test_root/legacy-conflict-state"
mkdir -p "$legacy_home" "$legacy_state"
stow --no-folding --dir "$fixture_repo" --target "$legacy_home" hypr-desktop gaming qmd
legacy_conflict_runner="$test_root/legacy-conflict.sh"
cat >"$legacy_conflict_runner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DOTFILES_INSTALL_SOURCE_ONLY=1
source "$FIXTURE_REPO/install.sh"
PLAN_JSON=$TEST_PLAN
PLAN_MODULES=()
BACKUP_DIR="$STATE_DIR/backups/legacy-conflict"
begin_migration
rm -- "$HOME/.config/hypr/config/legacy.lua"
ln -s /user/changed.lua "$HOME/.config/hypr/config/legacy.lua"
if remove_link_manifest "$MIGRATION_DIR/symlinks.tsv"; then exit 9; fi
[[ -L "$HOME/.config/hypr/config/monitors.lua" ]]
[[ -L "$HOME/.local/bin/game-run" ]]
EOF
chmod +x "$legacy_conflict_runner"
HOME="$legacy_home" XDG_CONFIG_HOME="$fixture_config" XDG_STATE_HOME="$legacy_state" \
	FIXTURE_REPO="$fixture_repo" TEST_PLAN="$empty_plan" "$legacy_conflict_runner"

# The implementation must enumerate only known module targets. A broad HOME
# scan would be slow and would cross unrelated user data on large machines.
# shellcheck disable=SC2016 # The test searches for this literal shell fragment.
if grep -Fq 'find "$HOME"' "$fixture_repo/install.sh"; then
	printf '%s\n' 'FAIL: la migración vuelve a recorrer HOME completo.' >&2
	exit 1
fi

printf '%s\n' 'PASS: la transacción revierte Stow, generados y archivos personales desde su snapshot'
