#!/usr/bin/env bash
set -euo pipefail

# Reproducible CachyOS/Noctalia setup for the Acer Aspire VX5-591G.
# Hardware, boot, GPU, Btrfs and firewall configuration are intentionally not
# changed here: CachyOS/chwd remain authoritative for those machine settings.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_CSV="$DOTFILES_DIR/packages.csv"
BACKUP_DIR="$HOME/config-backup-before-dotfiles-$(date +%Y%m%d-%H%M%S)"

readonly CATEGORY_COUNT=8
declare -A CATEGORY_NAME=(
  [1]="Escritorio Noctalia"
  [2]="Terminal"
  [3]="Teclado Hyper/Esc"
  [4]="Desarrollo"
  [5]="Archivos"
  [6]="Sistema portátil"
  [7]="Tema y fuentes"
  [8]="Multimedia"
)
declare -A CATEGORY_KEY=(
  [1]="core" [2]="terminal" [3]="keyboard" [4]="development"
  [5]="files" [6]="system" [7]="themes" [8]="media"
)
declare -A CATEGORY_STOW=(
  [1]="hypr-laptop noctalia mimeapps"
  [2]="ghostty fish starship zellij"
  [3]="kanata"
  [4]="nvim git micro codex"
  [5]=""
  [6]=""
  [7]="gtk kvantum fonts"
  [8]=""
)
declare -A SELECTED
for i in $(seq 1 "$CATEGORY_COUNT"); do SELECTED[$i]=0; done

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[AVISO]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

check_prerequisites() {
  [[ $EUID -ne 0 ]] || die "Ejecuta el instalador como usuario normal, no como root."
  command -v pacman >/dev/null || die "Esta configuración requiere Arch o CachyOS."
  [[ -f "$PACKAGES_CSV" ]] || die "No existe $PACKAGES_CSV."
  command -v git >/dev/null || die "Instala primero: sudo pacman -S --needed git base-devel"
  command -v stow >/dev/null || die "Instala primero: sudo pacman -S --needed stow"
  command -v shelly >/dev/null || die "Shelly no está instalado; usa el paquete oficial de CachyOS."
}

select_categories() {
  printf '\nConfiguración Acer VX: Noctalia, una pantalla, sin gaming ni Docker.\n'
  while true; do
    printf '\n'
    for i in $(seq 1 "$CATEGORY_COUNT"); do
      local mark=' '
      [[ ${SELECTED[$i]} -eq 1 ]] && mark='x'
      printf '  [%s] %d. %s\n' "$mark" "$i" "${CATEGORY_NAME[$i]}"
    done
    printf '\nNúmeros para alternar, a=todas, n=ninguna, Intro=continuar: '
    read -r choice
    case "$choice" in
      '') break ;;
      a|A) for i in $(seq 1 "$CATEGORY_COUNT"); do SELECTED[$i]=1; done ;;
      n|N) for i in $(seq 1 "$CATEGORY_COUNT"); do SELECTED[$i]=0; done ;;
      *)
        if [[ "$choice" =~ ^[1-8]$ ]]; then
          SELECTED[$choice]=$((1 - SELECTED[$choice]))
        fi
        ;;
    esac
  done
}

collect_packages() {
  local source=$1
  for i in $(seq 1 "$CATEGORY_COUNT"); do
    [[ ${SELECTED[$i]} -eq 1 ]] || continue
    local key=${CATEGORY_KEY[$i]}
    awk -F, -v category="$key" -v source="$source" \
      '$1 == category && $3 == source { print $2 }' "$PACKAGES_CSV"
  done
}

install_packages() {
  mapfile -t native_packages < <(collect_packages native)
  mapfile -t aur_packages < <(collect_packages aur)

  if ((${#native_packages[@]})); then
    info "Comprobando ${#native_packages[@]} paquetes de repositorios..."
    local missing=()
    for package in "${native_packages[@]}"; do
      pacman -Si "$package" >/dev/null 2>&1 || missing+=("$package")
    done
    ((${#missing[@]} == 0)) || die "Paquetes no encontrados: ${missing[*]}"
    shelly install standard "${native_packages[@]}"
  fi

  if ((${#aur_packages[@]})); then
    info "Shelly mostrará y pedirá revisar los paquetes AUR."
    shelly install aur "${aur_packages[@]}"
  fi
}

selected_stow_modules() {
  for i in $(seq 1 "$CATEGORY_COUNT"); do
    [[ ${SELECTED[$i]} -eq 1 ]] || continue
    for module in ${CATEGORY_STOW[$i]}; do printf '%s\n' "$module"; done
  done
}

backup_targets() {
  mapfile -t modules < <(selected_stow_modules)
  ((${#modules[@]})) || return 0
  mkdir -p "$BACKUP_DIR"

  for module in "${modules[@]}"; do
    [[ -d "$DOTFILES_DIR/$module" ]] || continue
    while IFS= read -r -d '' source; do
      local relative=${source#"$DOTFILES_DIR/$module/"}
      local target="$HOME/$relative"
      if [[ -e "$target" || -L "$target" ]]; then
        # Keep links already owned by this repository.
        if [[ -L "$target" ]] && [[ $(readlink -f "$target") == "$DOTFILES_DIR"/* ]]; then
          continue
        fi
        mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
        mv "$target" "$BACKUP_DIR/$relative"
      fi
    done < <(find "$DOTFILES_DIR/$module" \( -type f -o -type l \) -print0)
  done
  printf '%s\n' "$BACKUP_DIR" > "$HOME/.local/state/dotfiles-last-backup"
  ok "Copia reversible: $BACKUP_DIR"
}

deploy_dotfiles() {
  mapfile -t modules < <(selected_stow_modules)
  ((${#modules[@]})) || return 0
  info "Simulando Stow antes de aplicar..."
  stow --no-folding --restow --simulate --verbose=1 -d "$DOTFILES_DIR" -t "$HOME" "${modules[@]}"
  stow --no-folding --restow --verbose=1 -d "$DOTFILES_DIR" -t "$HOME" "${modules[@]}"
  ok "Dotfiles desplegados: ${modules[*]}"
}

finish_keyboard() {
  [[ ${SELECTED[3]} -eq 1 ]] || return 0
  warn "Kanata requiere la regla udev versionada en system-etc/udev/rules.d/."
  printf 'Instálala tras inspeccionar /dev/uinput; después habilita kanata.service.\n'
}

main() {
  check_prerequisites
  select_categories
  if ! selected_stow_modules | grep -q . && ! collect_packages native | grep -q .; then
    warn "No se seleccionó nada."
    exit 0
  fi
  printf '\nSe instalarán solo las categorías marcadas. ¿Continuar? [s/N] '
  read -r answer
  [[ $answer =~ ^[sS]$ ]] || exit 0
  install_packages
  backup_targets
  deploy_dotfiles
  finish_keyboard
  command -v fc-cache >/dev/null && fc-cache -f
  ok "Instalación terminada. Reinicia la sesión si cambiaste teclado o shell."
}

main "$@"
