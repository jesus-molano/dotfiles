# Gestión segura de dotfiles con GNU Stow.

dotfiles_dir := justfile_directory()
common_packages := "codex fish fonts ghostty git hypr-common kanata mimeapps noctalia nvim qutebrowser shell starship vscode zellij"
workstation_packages := common_packages + " hypr-laptop"
desktop_packages := common_packages + " hypr-desktop"
home_packages := common_packages + " hypr-laptop hypr-desktop"
system_packages := "sddm udev"

default:
    @just --justfile "{{ justfile() }}" --list

# Lista el perfil y los módulos permitidos (los paquetes heredados no se despliegan).
list:
    @printf 'workstation\n'
    @for package in {{ workstation_packages }}; do printf '  %s\n' "$package"; done
    @printf 'desktop\n'
    @for package in {{ desktop_packages }}; do printf '  %s\n' "$package"; done

# Simula de forma verbosa un perfil o un módulo permitido.
check target:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ dotfiles_dir }}"
    target={{ quote(target) }}
    read -r -a allowed <<< "{{ home_packages }}"

    if [[ "$target" == workstation ]]; then
        read -r -a packages <<< "{{ workstation_packages }}"
    elif [[ "$target" == desktop ]]; then
        read -r -a packages <<< "{{ desktop_packages }}"
    else
        packages=("$target")
    fi

    for package in "${packages[@]}"; do
        [[ " ${allowed[*]} " == *" $package "* ]] || {
            printf 'Módulo no permitido para HOME: %s\n' "$package" >&2
            exit 2
        }
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
    read -r -a allowed <<< "{{ home_packages }}"

    [[ "$target" != hypr-common && "$target" != hypr-laptop && "$target" != hypr-desktop ]] || {
        printf 'Los módulos Hyprland se aplican juntos: usa workstation o desktop.\n' >&2
        exit 2
    }

    if [[ "$target" == workstation || "$target" == desktop ]]; then
        exec "{{ dotfiles_dir }}/install.sh" "$target"
    fi

    if [[ "$target" == workstation ]]; then
        read -r -a packages <<< "{{ workstation_packages }}"
    elif [[ "$target" == desktop ]]; then
        read -r -a packages <<< "{{ desktop_packages }}"
    else
        packages=("$target")
    fi

    for package in "${packages[@]}"; do
        [[ " ${allowed[*]} " == *" $package "* ]] || {
            printf 'Módulo no permitido para HOME: %s\n' "$package" >&2
            exit 2
        }
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
    read -r -a allowed <<< "{{ home_packages }}"

    if [[ "$target" == workstation ]]; then
        read -r -a packages <<< "{{ workstation_packages }}"
    elif [[ "$target" == desktop ]]; then
        read -r -a packages <<< "{{ desktop_packages }}"
    else
        packages=("$target")
    fi

    for package in "${packages[@]}"; do
        [[ " ${allowed[*]} " == *" $package "* ]] || {
            printf 'Módulo no permitido para HOME: %s\n' "$package" >&2
            exit 2
        }
    done

    stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --delete --simulate --verbose=2 \
        --dir "{{ dotfiles_dir }}" --target "$HOME" "${packages[@]}"
    stow --no-folding --ignore='\.env.*' --ignore='btrfs-snapshots' --delete --verbose=2 \
        --dir "{{ dotfiles_dir }}" --target "$HOME" "${packages[@]}"

# Muestra de solo lectura qué cambiaría en el perfil workstation.
status:
    @just --justfile "{{ justfile() }}" check workstation

# Diagnóstico de solo lectura del perfil y del sistema anfitrión.
doctor:
    "{{ dotfiles_dir }}/scripts/doctor.sh"

# Comprueba la copia vendorizada, las tres skills instaladas y el MCP de Atlas.
atlas-check:
    "{{ dotfiles_dir }}/scripts/sync-project-atlas.sh" --check

# Instala copias reales de las skills y registra solo el bloque MCP de Atlas.
atlas-sync:
    "{{ dotfiles_dir }}/scripts/sync-project-atlas.sh" --apply

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
        target="$target_root/$relative"
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

    printf 'Destino exacto: %s\n' "$target_root"
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
        target="$target_root/$relative"
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
    "{{ dotfiles_dir }}/install.sh" "{{ profile }}"
