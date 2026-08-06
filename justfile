# Gestión segura de dotfiles con GNU Stow.

dotfiles_dir := justfile_directory()
system_packages := "sddm udev snapper systemd"

default:
    @just --justfile "{{ justfile() }}" --list

# Lista el perfil y los módulos permitidos (los paquetes heredados no se despliegan).
list:
    #!/usr/bin/env bash
    set -euo pipefail
    source "{{ dotfiles_dir }}/profiles.sh"
    for profile in workstation desktop; do
        printf '%s\n' "$profile"
        while IFS= read -r package; do printf '  %s\n' "$package"; done < <(profile_modules "$profile")
    done

# Simula de forma verbosa un perfil o un módulo permitido.
check target:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ dotfiles_dir }}"
    target={{ quote(target) }}
    source "{{ dotfiles_dir }}/profiles.sh"

    if profile_is_valid "$target"; then
        mapfile -t packages < <(profile_modules "$target")
    elif home_module_is_allowed "$target"; then
        packages=("$target")
    else
        printf 'Módulo no permitido para HOME: %s\n' "$target" >&2
        exit 2
    fi

    for package in "${packages[@]}"; do
        [[ -d "$package" ]] || {
            printf 'No existe el módulo: %s\n' "$package" >&2
            exit 2
        }
    done

    stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --adopt --simulate --verbose=2 \
        --dir "{{ dotfiles_dir }}" --target "$HOME" "${packages[@]}"

# Aplica un perfil o módulo permitido; siempre simula antes y requiere destino.
apply target:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ dotfiles_dir }}"
    target={{ quote(target) }}
    source "{{ dotfiles_dir }}/profiles.sh"

    if profile_is_valid "$target"; then
        exec "{{ dotfiles_dir }}/install.sh" "$target"
    fi

    [[ "$target" != gaming && "$target" != backup ]] || {
        printf 'Los módulos gaming y backup solo se aplican con el perfil desktop: usa just apply desktop.\n' >&2
        exit 2
    }

    [[ "$target" != hypr-common && "$target" != hypr-laptop && "$target" != hypr-desktop ]] || {
        printf 'Los módulos Hyprland se aplican juntos: usa workstation o desktop.\n' >&2
        exit 2
    }

    home_module_is_allowed "$target" || {
        printf 'Módulo no permitido para HOME: %s\n' "$target" >&2
        exit 2
    }
    packages=("$target")

    for package in "${packages[@]}"; do
        [[ -d "$package" ]] || {
            printf 'No existe el módulo: %s\n' "$package" >&2
            exit 2
        }
    done

    stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --simulate --verbose=2 \
        --dir "{{ dotfiles_dir }}" --target "$HOME" "${packages[@]}"
    stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --restow --verbose=2 \
        --dir "{{ dotfiles_dir }}" --target "$HOME" "${packages[@]}"

# Retira enlaces de un perfil o módulo permitido; nunca acepta una llamada vacía.
remove target:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ dotfiles_dir }}"
    target={{ quote(target) }}
    source "{{ dotfiles_dir }}/profiles.sh"

    if profile_is_valid "$target"; then
        mapfile -t packages < <(profile_modules "$target")
    elif home_module_is_allowed "$target"; then
        packages=("$target")
    else
        printf 'Módulo no permitido para HOME: %s\n' "$target" >&2
        exit 2
    fi

    stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --delete --simulate --verbose=2 \
        --dir "{{ dotfiles_dir }}" --target "$HOME" "${packages[@]}"
    stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --delete --verbose=2 \
        --dir "{{ dotfiles_dir }}" --target "$HOME" "${packages[@]}"

# Muestra de solo lectura qué cambiaría en el perfil indicado.
status profile:
    @just --justfile "{{ justfile() }}" check {{ quote(profile) }}

# Diagnóstico de solo lectura del perfil y del sistema anfitrión.
doctor profile="":
    "{{ dotfiles_dir }}/scripts/doctor.sh" "{{ profile }}"

# Valida la rama en un HOME temporal, sin depender del despliegue activo.
lint profile="desktop":
    "{{ dotfiles_dir }}/scripts/doctor.sh" {{ quote(profile) }} --config-only

# Simula el despliegue contra el HOME real sin escribir.
plan profile="desktop":
    @just --justfile "{{ justfile() }}" check {{ quote(profile) }}

# Audita solo el estado vivo del host ya desplegado.
doctor-live profile="desktop":
    "{{ dotfiles_dir }}/scripts/doctor.sh" {{ quote(profile) }} --live-only

# Comprueba la copia vendorizada, las tres skills instaladas y el MCP de Atlas.
atlas-check:
    "{{ dotfiles_dir }}/scripts/sync-project-atlas.sh" --check

# Instala copias reales de las skills y registra solo el bloque MCP de Atlas.
atlas-sync:
    "{{ dotfiles_dir }}/scripts/sync-project-atlas.sh" --apply

# Comprueba las preferencias duraderas sin leer ni reemplazar hooks o MCP.
codex-check:
    "{{ dotfiles_dir }}/scripts/sync-codex-config.py" --check
    "{{ dotfiles_dir }}/scripts/clean-codex-rules.sh" --check

# Sincroniza preferencias Codex con destino exacto, confirmación y backup.
codex-sync:
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

# Ejecuta el instalador explícito de un perfil permitido.
install profile="workstation":
    "{{ dotfiles_dir }}/install.sh" {{ quote(profile) }}

# Lista, sin modificar nada, los paquetes seleccionados para un perfil.
packages profile:
    @"{{ dotfiles_dir }}/install.sh" {{ quote(profile) }} --list-packages
