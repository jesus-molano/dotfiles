# Gestión segura de dotfiles con GNU Stow.

dotfiles_dir := justfile_directory()
system_packages := "sddm udev snapper systemd"

default:
    @just --justfile "{{ justfile() }}" --list

# Lista la composición resuelta; no necesita perfiles.
list:
    @python3 "{{ dotfiles_dir }}/scripts/dotfiles_host.py" --repo "{{ dotfiles_dir }}" show --safe-defaults

# Simula la composición local contra un HOME temporal. No acepta perfiles.
check:
    #!/usr/bin/env bash
    set -euo pipefail
    "{{ dotfiles_dir }}/scripts/stow-lint.sh"

apply:
    "{{ dotfiles_dir }}/install.sh"

# Retira exactamente la última composición aplicada, no una detección actual.
# También retira sus artefactos generados registrados; conserva paquetes y backups.
remove:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 "{{ dotfiles_dir }}/scripts/dotfiles_host.py" --repo "{{ dotfiles_dir }}" retire
    printf '%s\n' 'Se retirarán solo los enlaces y generados del último plan aplicado.'
    printf '%s\n' 'No se desinstalan paquetes ni se eliminan backups; dotf host rollback puede restaurar el estado anterior.'
    printf 'Escribe RETIRAR: '
    read -r confirmation
    [[ "$confirmation" == RETIRAR ]] || { printf '%s\n' 'Cancelado sin cambios.'; exit 1; }
    python3 "{{ dotfiles_dir }}/scripts/dotfiles_host.py" --repo "{{ dotfiles_dir }}" retire --apply

# Muestra de solo lectura qué cambiaría en el host actual.
status:
    "{{ dotfiles_dir }}/install.sh" --check

# Diagnóstico de solo lectura de la composición local y del sistema anfitrión.
doctor:
    "{{ dotfiles_dir }}/scripts/doctor.sh"

# Valida la rama en un HOME temporal, sin depender del despliegue activo.
lint:
    "{{ dotfiles_dir }}/scripts/doctor.sh" --config-only

# Suite portable ejecutable en Arch CI sin hardware, sesión gráfica ni secretos.
ci:
    "{{ dotfiles_dir }}/scripts/ci-check.sh"

# Simula el despliegue contra HOME sin escribir.
plan:
    @just --justfile "{{ justfile() }}" status

# Audita solo el estado vivo del host ya desplegado.
doctor-live:
    "{{ dotfiles_dir }}/scripts/doctor.sh" --live-only

# Descarga de forma explícita el modelo local de dictado. No se ejecuta durante Stow.
dictation-setup model="base":
    "{{ dotfiles_dir }}/hypr-common/.local/bin/local-dictation" setup {{ quote(model) }}

# AI clients (Claude Code and Codex) from the neutral source in ai/.
# Preview the exact files and keys that ai-sync would change.
ai-plan:
    python3 "{{ dotfiles_dir }}/scripts/sync-ai.py" plan

# Apply ai/ to both clients in one transaction with a private backup.
ai-sync:
    python3 "{{ dotfiles_dir }}/scripts/sync-ai.py" apply

# Verify the sandbox dependencies (Linux), the deployed state, generated files, skills and tests without writing.
ai-check:
    @if [ "$(uname -s)" = Linux ]; then missing=""; for tool in bwrap socat; do command -v "$tool" >/dev/null || missing="$missing $tool"; done; if [ -n "$missing" ]; then echo "ERROR: sandbox dependencies missing:$missing; Claude Code runs commands unsandboxed"; exit 1; fi; echo 'OK: bwrap and socat found. The optional seccomp filter (Unix socket blocking) shows only in /sandbox: a Dependencies tab means it is missing.'; fi
    python3 "{{ dotfiles_dir }}/scripts/sync-ai.py" check
    python3 "{{ dotfiles_dir }}/scripts/render-ai.py" --check
    @just --justfile "{{ justfile() }}" skills-check
    @just --justfile "{{ justfile() }}" ai-tests
    python3 "{{ dotfiles_dir }}/scripts/check-skills.py" --agents-root "${CODEX_HOME:-$HOME/.codex}/agents" --required-agent reuse-scout --required-agent catalog-writer --installed-skills-root "$HOME/.agents/skills"
    @if command -v claude >/dev/null; then claude plugin validate "{{ dotfiles_dir }}/ai/skills"; else echo 'claude not installed: skipped plugin validate'; fi
    @just --justfile "{{ justfile() }}" ai-mods-check

# Validate and test the Claude Code mods in ai/mods (no session, sign-in or network).
ai-mods-check:
    @if command -v claude >/dev/null; then for manifest in "{{ dotfiles_dir }}"/ai/mods/*/.claude-plugin/plugin.json; do [ -f "$manifest" ] || continue; mod="${manifest%/.claude-plugin/plugin.json}"; claude plugin validate --strict "$mod" && claude plugin test "$mod" || exit 1; done; else echo 'claude not installed: skipped mods'; fi

# Measure skill routing with real runs (costs tokens; defaults: 1 run per case, $4 cap). --outcome compares with and without the skills ($4 cap).
ai-eval *args:
    "{{ dotfiles_dir }}/scripts/ai-eval.sh" {{ args }}

# Static checks of the versioned skills and Codex agent files (also run by CI).
skills-check:
    python3 "{{ dotfiles_dir }}/scripts/check-skills.py" --required-agent reuse-scout --required-agent catalog-writer

# Python regressions for the AI tooling, without writing bytecode to the repository.
ai-tests:
    env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "{{ dotfiles_dir }}/scripts/tests" -p 'test_*.py'

# Prepara Node en mise y muestra si fnm siguen pendientes de migración.
toolchain-check:
    "{{ dotfiles_dir }}/scripts/migrate-node-to-mise.sh" --check

# Retira fnm solo tras validar mise; con rollback.
toolchain-migrate:
    "{{ dotfiles_dir }}/scripts/migrate-node-to-mise.sh" --apply

# Compara la instalación y la receta fijada con la última release oficial.
codexbar-check:
    "{{ dotfiles_dir }}/scripts/codexbar-official" check

# Verifica el checksum oficial y prueba CodexBar sin instalarlo.
codexbar-test:
    "{{ dotfiles_dir }}/scripts/codexbar-official" test

# Prueba y construye mediante Shelly la receta oficial revisada.
codexbar-build:
    "{{ dotfiles_dir }}/scripts/codexbar-official" build

# Comprueba el SDK Android local sin descargar herramientas ni aceptar licencias.
android-check:
    "{{ dotfiles_dir }}/android/.local/bin/android-sdk-check"

# Revisa los timers de usuario de backup sin activarlos.
check-user-timers:
    @systemctl --user is-enabled restic-backup.timer restic-maintenance.timer || true
    @systemctl --user list-timers restic-backup.timer restic-maintenance.timer --no-pager

# Activa únicamente los dos timers Restic tras desplegar y configurar secretos.
apply-user-timers:
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%s\n' 'Unidades exactas: restic-backup.timer y restic-maintenance.timer (usuario actual).'
    printf 'Escribe ACTIVAR: '
    read -r confirmation
    [[ "$confirmation" == ACTIVAR ]] || {
        printf '%s\n' 'Cancelado sin cambios.'
        exit 1
    }
    systemctl --user daemon-reload
    systemctl --user enable --now restic-backup.timer restic-maintenance.timer

# Revisa el mantenimiento físico existente sin cambiar servicios.
check-maintenance:
    @systemctl is-enabled btrfs-scrub@-.timer smartd.service || true
    @systemctl list-timers btrfs-scrub@-.timer --no-pager
    @just --justfile "{{ justfile() }}" check-system snapper

# Activa solo las unidades inspeccionadas; la configuración Snapper se aplica aparte.
apply-maintenance:
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%s\n' 'Unidades exactas: btrfs-scrub@-.timer y smartd.service.'
    printf '%s\n' 'Rollback: pkexec systemctl disable --now btrfs-scrub@-.timer smartd.service'
    printf 'Escribe ACTIVAR: '
    read -r confirmation
    [[ "$confirmation" == ACTIVAR ]] || {
        printf '%s\n' 'Cancelado sin cambios.'
        exit 1
    }
    pkexec /usr/bin/systemctl enable --now btrfs-scrub@-.timer smartd.service

# Revisa un módulo de sistema permitido sin escribir en /etc.
check-system module:
    #!/usr/bin/env bash
    set -euo pipefail
    "{{ dotfiles_dir }}/scripts/system-etc-transaction.sh" --check {{ quote(module) }}

# Instala copias en /etc con confirmación y backup; no crea enlaces a HOME.
apply-system module:
    #!/usr/bin/env bash
    set -euo pipefail
    module={{ quote(module) }}
    read -r -a allowed <<< "{{ system_packages }}"
    [[ " ${allowed[*]} " == *" $module "* ]] || {
        printf 'Módulo de sistema no permitido: %s\n' "$module" >&2
        exit 2
    }

    source_root="{{ dotfiles_dir }}/system-etc/$module"
    target_root="/etc/$module"
    [[ -d "$source_root" ]] || {
        printf 'No existe el módulo: %s\n' "$source_root" >&2
        exit 2
    }

    if [[ "$module" == sddm ]]; then
        printf 'Destinos exactos: /etc/sddm.conf.d y /etc/sddm/themes\n'
    else
        printf 'Destino exacto: %s\n' "$target_root"
    fi
    printf 'Se copiarán archivos y se respaldarán los existentes. Escribe APLICAR: '
    read -r confirmation
    [[ "$confirmation" == APLICAR ]] || {
        printf 'Cancelado sin cambios.\n'
        exit 1
    }

    "{{ dotfiles_dir }}/scripts/system-etc-transaction.sh" --apply "$module"

# No instala ni recarga otros módulos de /etc.
# Activa únicamente el automount de backups después de aplicar system-etc.
apply-backup-automount:
    #!/usr/bin/env bash
    set -euo pipefail
    mount_unit=/etc/systemd/system/mnt-backups.mount
    automount_unit=/etc/systemd/system/mnt-backups.automount
    for unit in "$mount_unit" "$automount_unit"; do
        [[ -f "$unit" && ! -L "$unit" ]] || {
            printf 'Falta la unidad aplicada por system-etc: %s\n' "$unit" >&2
            printf '%s\n' 'Ejecuta primero: just apply-system systemd'
            exit 2
        }
    done
    printf 'Unidades exactas: %s y %s\n' "$mount_unit" "$automount_unit"
    printf '%s\n' 'Acciones: daemon-reload y enable --now de mnt-backups.automount.'
    printf '%s\n' 'Rollback exacto: pkexec systemctl disable --now mnt-backups.automount; pkexec systemctl daemon-reload'
    printf '%s\n' 'No se modificará ningún otro módulo ni unidad.'
    printf 'Escribe ACTIVAR: '
    read -r confirmation
    [[ "$confirmation" == ACTIVAR ]] || {
        printf 'Cancelado sin cambios.\n'
        exit 1
    }
    pkexec /usr/bin/systemctl daemon-reload
    pkexec /usr/bin/systemctl enable --now mnt-backups.automount
    /usr/bin/systemctl is-enabled --quiet mnt-backups.automount
    /usr/bin/systemctl is-active --quiet mnt-backups.automount

# Ejecuta el instalador de la composición local.
install:
    "{{ dotfiles_dir }}/install.sh"

# Lista, sin modificar nada, los paquetes seleccionados.
packages:
    @"{{ dotfiles_dir }}/install.sh" --list-packages
