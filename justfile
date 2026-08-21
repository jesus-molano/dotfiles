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

# Simula el despliegue contra HOME sin escribir.
plan:
    @just --justfile "{{ justfile() }}" status

# Audita solo el estado vivo del host ya desplegado.
doctor-live:
    "{{ dotfiles_dir }}/scripts/doctor.sh" --live-only

# Descarga de forma explícita el modelo local de dictado. No se ejecuta durante Stow.
dictation-setup model="base":
    "{{ dotfiles_dir }}/hypr-common/.local/bin/local-dictation" setup {{ quote(model) }}

# Comprueba la copia vendorizada, las tres skills instaladas y el MCP de Atlas.
atlas-check:
    "{{ dotfiles_dir }}/scripts/sync-project-atlas.sh" --check

# Instala copias reales de las skills y registra solo el bloque MCP de Atlas.
atlas-sync:
    "{{ dotfiles_dir }}/scripts/sync-project-atlas.sh" --apply

# Valida todas las skills locales y los agentes TOML de Codex sin escribir.
codex-skills-check:
    "{{ dotfiles_dir }}/scripts/check-codex-skills.py"

# Ejecuta las regresiones del tooling Codex sin generar bytecode en el repositorio.
codex-tests:
    env PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s "{{ dotfiles_dir }}/scripts/tests" -p 'test_*.py'

# Comprueba skills, regresiones y preferencias sin reemplazar hooks o MCP.
codex-check:
    @just --justfile "{{ justfile() }}" codex-skills-check
    @just --justfile "{{ justfile() }}" codex-tests
    "{{ dotfiles_dir }}/scripts/manage-codex-skill-links.sh" --check
    "{{ dotfiles_dir }}/scripts/sync-codex-config.py" --check
    "{{ dotfiles_dir }}/scripts/clean-codex-rules.sh" --check

# Sincroniza solo las preferencias gestionadas de Codex con confirmación y backup.
codex-config-sync:
    "{{ dotfiles_dir }}/scripts/sync-codex-config.py" --apply

# Retira solo las reglas temporales exactas detectadas durante la investigación.
codex-clean-rules:
    "{{ dotfiles_dir }}/scripts/clean-codex-rules.sh" --apply

# Prepara Node en mise y muestra si fnm/Atlas siguen pendientes de migración.
toolchain-check:
    "{{ dotfiles_dir }}/scripts/migrate-node-to-mise.sh" --check

# Retira fnm solo tras validar mise; reconfigura y prueba Atlas con rollback.
toolchain-migrate:
    "{{ dotfiles_dir }}/scripts/migrate-node-to-mise.sh" --apply

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

    while IFS= read -r -d '' source; do
        relative="${source#"$source_root/"}"
        if [[ "$module" == sddm && "$relative" == conf.d/* ]]; then
            target="/etc/sddm.conf.d/${relative#conf.d/}"
        else
            target="$target_root/$relative"
        fi
        if [[ -e "$target" ]] && cmp -s "$source" "$target"; then
            printf '= %s\n' "$target"
        elif [[ -e "$target" ]]; then
            printf '~ %s\n' "$target"
            diff -u --label "$target (actual)" --label "$source (propuesto)" \
                "$target" "$source" || true
        else
            printf '+ %s\n' "$target"
        fi
    done < <(find "$source_root" -type f -print0 | sort -z)

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

    state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
    backup_root="$state_root/system-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_root"

    while IFS= read -r -d '' source; do
        relative="${source#"$source_root/"}"
        if [[ "$module" == sddm && "$relative" == conf.d/* ]]; then
            target="/etc/sddm.conf.d/${relative#conf.d/}"
        else
            target="$target_root/$relative"
        fi
        if [[ -e "$target" ]] && cmp -s "$source" "$target"; then
            printf '= %s (sin cambios)\n' "$target"
            continue
        fi
        if [[ -e "$target" || -L "$target" ]]; then
            pkexec /usr/bin/cp --archive --parents "$target" "$backup_root"
        fi
        mode="$(stat -c '%a' "$source")"
        pkexec /usr/bin/install -D -m "$mode" "$source" "$target"
        printf '✓ %s\n' "$target"
    done < <(find "$source_root" -type f -print0 | sort -z)

    printf '%s\n' "$backup_root" > "$state_root/last-system-backup"
    printf 'Backup: %s\n' "$backup_root"

# Ejecuta el instalador de la composición local.
install:
    "{{ dotfiles_dir }}/install.sh"

# Lista, sin modificar nada, los paquetes seleccionados.
packages:
    @"{{ dotfiles_dir }}/install.sh" --list-packages
