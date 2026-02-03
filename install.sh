#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# CachyOS + Hyprland Dotfiles Installer
# ──────────────────────────────────────────────

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
PACKAGES_CSV="$DOTFILES_DIR/packages.csv"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Category definitions: name, description, stow packages
declare -A CAT_DESC=(
    [1]="Core Desktop"
    [2]="Terminal"
    [3]="Keyboard"
    [4]="Themes"
    [5]="Gaming"
    [6]="Development"
    [7]="System"
    [8]="NVIDIA"
    [9]="Hardware"
    [10]="Browsers"
    [11]="Media"
)

declare -A CAT_KEY=(
    [1]="core"
    [2]="terminal"
    [3]="keyboard"
    [4]="themes"
    [5]="gaming"
    [6]="development"
    [7]="system"
    [8]="nvidia"
    [9]="hardware"
    [10]="browsers"
    [11]="media"
)

declare -A CAT_STOW=(
    [1]="hypr waybar rofi swaync mimeapps"
    [2]="kitty fish starship zellij shell"
    [3]="kanata"
    [4]="gtk kvantum fonts"
    [5]="gaming"
    [6]="git npm micro claude"
    [7]=""
    [8]=""
    [9]=""
    [10]=""
    [11]=""
)

# Track which categories are selected (all on by default)
declare -A SELECTED
for i in $(seq 1 11); do
    SELECTED[$i]=1
done

# ──────────────────────────────────────────────
# Functions
# ──────────────────────────────────────────────

banner() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
     ██████╗ █████╗  ██████╗██╗  ██╗██╗   ██╗ ██████╗ ███████╗
    ██╔════╝██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝██╔═══██╗██╔════╝
    ██║     ███████║██║     ███████║ ╚████╔╝ ██║   ██║███████╗
    ██║     ██╔══██║██║     ██╔══██║  ╚██╔╝  ██║   ██║╚════██║
    ╚██████╗██║  ██║╚██████╗██║  ██║   ██║   ╚██████╔╝███████║
     ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD}  Hyprland + Catppuccin Mocha Dotfiles Installer${NC}"
    echo -e "${CYAN}  github.com/jesus-molano/dotfiles${NC}"
    echo ""
}

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Not root
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root."
        exit 1
    fi

    # Arch-based
    if ! command -v pacman &>/dev/null; then
        log_error "pacman not found. This script requires Arch Linux or CachyOS."
        exit 1
    fi

    # Internet
    if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
        log_error "No internet connection detected."
        exit 1
    fi

    # packages.csv exists
    if [[ ! -f "$PACKAGES_CSV" ]]; then
        log_error "packages.csv not found at $PACKAGES_CSV"
        exit 1
    fi

    log_ok "All prerequisites met."
}

install_paru() {
    if command -v paru &>/dev/null; then
        log_ok "paru is already installed."
        return
    fi

    log_info "Installing paru (AUR helper)..."
    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$tmpdir/paru-bin"
    (cd "$tmpdir/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    log_ok "paru installed."
}

install_stow() {
    if command -v stow &>/dev/null; then
        log_ok "stow is already installed."
        return
    fi

    log_info "Installing GNU Stow..."
    sudo pacman -S --noconfirm stow
    log_ok "stow installed."
}

display_menu() {
    while true; do
        clear
        banner
        echo -e "${BOLD}  Select categories to install:${NC}"
        echo ""

        for i in $(seq 1 11); do
            local mark
            if [[ ${SELECTED[$i]} -eq 1 ]]; then
                mark="${GREEN}[x]${NC}"
            else
                mark="${RED}[ ]${NC}"
            fi

            local stow_info=""
            if [[ -n "${CAT_STOW[$i]}" ]]; then
                stow_info="${CYAN}(stow: ${CAT_STOW[$i]})${NC}"
            fi

            # Count packages in category
            local key="${CAT_KEY[$i]}"
            local pkg_count
            pkg_count=$(grep -c "^${key}," "$PACKAGES_CSV" 2>/dev/null || echo 0)

            printf "  %s %2d. %-16s %s %s\n" "$mark" "$i" "${CAT_DESC[$i]}" "${YELLOW}(${pkg_count} pkgs)${NC}" "$stow_info"
        done

        echo ""
        echo -e "  ${BOLD}a${NC} = select all | ${BOLD}n${NC} = select none | ${BOLD}Enter${NC} = confirm"
        echo ""
        read -rp "  Toggle [1-11/a/n/Enter]: " choice

        case "$choice" in
            "")  break ;;
            a|A) for i in $(seq 1 11); do SELECTED[$i]=1; done ;;
            n|N) for i in $(seq 1 11); do SELECTED[$i]=0; done ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= 11 )); then
                    if [[ ${SELECTED[$choice]} -eq 1 ]]; then
                        SELECTED[$choice]=0
                    else
                        SELECTED[$choice]=1
                    fi
                fi
                ;;
        esac
    done
}

install_packages() {
    local packages=()

    for i in $(seq 1 11); do
        if [[ ${SELECTED[$i]} -eq 1 ]]; then
            local key="${CAT_KEY[$i]}"
            while IFS=',' read -r cat pkg _; do
                if [[ "$cat" == "$key" ]]; then
                    packages+=("$pkg")
                fi
            done < "$PACKAGES_CSV"
        fi
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warn "No packages selected."
        return
    fi

    log_info "Installing ${#packages[@]} packages..."
    paru -S --needed --noconfirm "${packages[@]}"
    log_ok "Packages installed."
}

backup_configs() {
    local stow_pkgs=()

    for i in $(seq 1 11); do
        if [[ ${SELECTED[$i]} -eq 1 ]] && [[ -n "${CAT_STOW[$i]}" ]]; then
            for pkg in ${CAT_STOW[$i]}; do
                stow_pkgs+=("$pkg")
            done
        fi
    done

    if [[ ${#stow_pkgs[@]} -eq 0 ]]; then
        return
    fi

    log_info "Backing up existing configs to $BACKUP_DIR..."
    local backed_up=0

    for pkg in "${stow_pkgs[@]}"; do
        local pkg_dir="$DOTFILES_DIR/$pkg"
        [[ ! -d "$pkg_dir" ]] && continue

        # Find all files that stow would create and back up existing ones
        while IFS= read -r -d '' file; do
            local rel="${file#"$pkg_dir"/}"
            local target="$HOME/$rel"

            if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
                local backup_path="$BACKUP_DIR/$rel"
                mkdir -p "$(dirname "$backup_path")"
                mv "$target" "$backup_path"
                backed_up=$((backed_up + 1))
            elif [[ -L "$target" ]]; then
                rm -f "$target"
            fi
        done < <(find "$pkg_dir" -type f -print0 -o -type l -print0)
    done

    if [[ $backed_up -gt 0 ]]; then
        log_ok "Backed up $backed_up files to $BACKUP_DIR"
    else
        log_info "No existing configs to back up."
    fi
}

stow_packages() {
    local stow_pkgs=()

    for i in $(seq 1 11); do
        if [[ ${SELECTED[$i]} -eq 1 ]] && [[ -n "${CAT_STOW[$i]}" ]]; then
            for pkg in ${CAT_STOW[$i]}; do
                stow_pkgs+=("$pkg")
            done
        fi
    done

    if [[ ${#stow_pkgs[@]} -eq 0 ]]; then
        log_warn "No stow packages to deploy."
        return
    fi

    log_info "Deploying dotfiles via stow..."

    for pkg in "${stow_pkgs[@]}"; do
        if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
            stow -d "$DOTFILES_DIR" -t "$HOME" "$pkg" 2>/dev/null && \
                log_ok "Stowed: $pkg" || \
                log_warn "Conflict stowing: $pkg (run 'stow -d $DOTFILES_DIR -t $HOME $pkg' manually)"
        fi
    done
}

post_stow_fixes() {
    # Fix .npmrc hardcoded home path
    if [[ -f "$HOME/.npmrc" ]]; then
        sed -i "s|/home/jesus|$HOME|g" "$HOME/.npmrc"
        log_ok "Patched .npmrc home path."
    fi

    # Verify GTK symlinks point to valid targets
    if [[ -L "$HOME/.config/gtk-4.0/gtk.css" ]]; then
        if [[ ! -e "$HOME/.config/gtk-4.0/gtk.css" ]]; then
            log_warn "GTK symlink target missing. Install catppuccin-gtk-theme-mocha first."
        else
            log_ok "GTK-4.0 symlinks valid."
        fi
    fi

    # Deploy /etc/ configs from system-etc/
    local etc_dir="$DOTFILES_DIR/system-etc"

    # Network tuning (System category)
    if [[ ${SELECTED[7]} -eq 1 ]] && [[ -f "$etc_dir/sysctl.d/99-network-performance.conf" ]]; then
        echo ""
        read -rp "$(echo -e "${YELLOW}  Apply network tuning to /etc/? (requires sudo) [s/N]:${NC} ")" net_confirm
        if [[ "$net_confirm" =~ ^[sS]$ ]]; then
            sudo cp "$etc_dir/sysctl.d/99-network-performance.conf" /etc/sysctl.d/ && \
                log_ok "Installed: /etc/sysctl.d/99-network-performance.conf"
            sudo cp "$etc_dir/NetworkManager/conf.d/wifi-powersave-off.conf" /etc/NetworkManager/conf.d/ && \
                log_ok "Installed: /etc/NetworkManager/conf.d/wifi-powersave-off.conf"
            sudo sysctl --system &>/dev/null && \
                log_ok "Applied sysctl settings."
        else
            log_info "Skipped network config."
        fi
    fi

    # Gaming sysctl (Gaming category)
    if [[ ${SELECTED[5]} -eq 1 ]] && [[ -f "$etc_dir/sysctl.d/99-gaming.conf" ]]; then
        echo ""
        read -rp "$(echo -e "${YELLOW}  Apply gaming sysctl tuning to /etc/? (requires sudo) [s/N]:${NC} ")" gaming_confirm
        if [[ "$gaming_confirm" =~ ^[sS]$ ]]; then
            sudo cp "$etc_dir/sysctl.d/99-gaming.conf" /etc/sysctl.d/ && \
                log_ok "Installed: /etc/sysctl.d/99-gaming.conf"
            sudo sysctl --system &>/dev/null && \
                log_ok "Applied sysctl settings."
        else
            log_info "Skipped gaming sysctl config."
        fi
    fi

    # Kanata udev rules (Keyboard category)
    if [[ ${SELECTED[3]} -eq 1 ]] && [[ -f "$etc_dir/udev/rules.d/99-kanata.rules" ]]; then
        echo ""
        read -rp "$(echo -e "${YELLOW}  Install kanata udev rules to /etc/? (requires sudo) [s/N]:${NC} ")" kanata_confirm
        if [[ "$kanata_confirm" =~ ^[sS]$ ]]; then
            sudo cp "$etc_dir/udev/rules.d/99-kanata.rules" /etc/udev/rules.d/ && \
                log_ok "Installed: /etc/udev/rules.d/99-kanata.rules"
            sudo udevadm control --reload-rules && sudo udevadm trigger && \
                log_ok "Reloaded udev rules."
        else
            log_info "Skipped kanata udev rules."
        fi
    fi

    # NVIDIA mkinitcpio modules (NVIDIA category)
    if [[ ${SELECTED[8]} -eq 1 ]]; then
        echo ""
        read -rp "$(echo -e "${YELLOW}  Add NVIDIA modules to mkinitcpio.conf? (requires sudo) [s/N]:${NC} ")" nvidia_confirm
        if [[ "$nvidia_confirm" =~ ^[sS]$ ]]; then
            if grep -q "^MODULES=.*nvidia" /etc/mkinitcpio.conf 2>/dev/null; then
                log_info "NVIDIA modules already present in mkinitcpio.conf."
            else
                sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm \1)/' /etc/mkinitcpio.conf && \
                    log_ok "Added NVIDIA modules to /etc/mkinitcpio.conf"
                sudo mkinitcpio -P && \
                    log_ok "Regenerated initramfs."
            fi
        else
            log_info "Skipped NVIDIA mkinitcpio config."
        fi
    fi

    # zram-generator config (System category)
    if [[ ${SELECTED[7]} -eq 1 ]] && [[ -f "$etc_dir/zram-generator/zram-generator.conf" ]]; then
        echo ""
        read -rp "$(echo -e "${YELLOW}  Install zram-generator config to /etc/? (requires sudo) [s/N]:${NC} ")" zram_confirm
        if [[ "$zram_confirm" =~ ^[sS]$ ]]; then
            sudo mkdir -p /etc/systemd
            sudo cp "$etc_dir/zram-generator/zram-generator.conf" /etc/systemd/zram-generator.conf && \
                log_ok "Installed: /etc/systemd/zram-generator.conf"
            log_info "zram will be active after reboot."
        else
            log_info "Skipped zram-generator config."
        fi
    fi

    # UFW firewall setup (System category)
    if [[ ${SELECTED[7]} -eq 1 ]] && command -v ufw &>/dev/null; then
        echo ""
        read -rp "$(echo -e "${YELLOW}  Configure UFW firewall? (requires sudo) [s/N]:${NC} ")" ufw_confirm
        if [[ "$ufw_confirm" =~ ^[sS]$ ]]; then
            sudo ufw default deny incoming && \
                log_ok "UFW: default deny incoming"
            sudo ufw default allow outgoing && \
                log_ok "UFW: default allow outgoing"
            sudo ufw allow 1714:1764/udp && \
                log_ok "UFW: allowed KDE Connect UDP"
            sudo ufw allow 1714:1764/tcp && \
                log_ok "UFW: allowed KDE Connect TCP"
            sudo ufw --force enable && \
                log_ok "UFW: enabled"
            sudo systemctl enable --now ufw && \
                log_ok "UFW: systemd service enabled"
        else
            log_info "Skipped UFW configuration."
        fi
    fi

    # Snapper Btrfs snapshots (System category)
    if [[ ${SELECTED[7]} -eq 1 ]] && command -v snapper &>/dev/null; then
        echo ""
        read -rp "$(echo -e "${YELLOW}  Configure Snapper for Btrfs snapshots? (requires sudo) [s/N]:${NC} ")" snapper_confirm
        if [[ "$snapper_confirm" =~ ^[sS]$ ]]; then

            # --- Config: root (/) ---
            if ! sudo snapper -c root get-config &>/dev/null 2>&1; then
                sudo snapper -c root create-config /
                log_ok "Snapper: created root config"
            else
                log_info "Snapper: root config already exists"
            fi

            # Timeline settings for root
            sudo snapper -c root set-config \
                TIMELINE_CREATE=yes \
                TIMELINE_CLEANUP=yes \
                TIMELINE_MIN_AGE=1800 \
                TIMELINE_LIMIT_HOURLY=5 \
                TIMELINE_LIMIT_DAILY=7 \
                TIMELINE_LIMIT_WEEKLY=4 \
                TIMELINE_LIMIT_MONTHLY=6 \
                TIMELINE_LIMIT_YEARLY=0

            # Number cleanup (for snap-pac)
            sudo snapper -c root set-config \
                NUMBER_CLEANUP=yes \
                NUMBER_MIN_AGE=1800 \
                NUMBER_LIMIT=50 \
                NUMBER_LIMIT_IMPORTANT=10

            # --- Config: home (/home) ---
            if ! sudo snapper -c home get-config &>/dev/null 2>&1; then
                sudo snapper -c home create-config /home
                log_ok "Snapper: created home config"
            else
                log_info "Snapper: home config already exists"
            fi

            # Timeline settings for home (less aggressive)
            sudo snapper -c home set-config \
                TIMELINE_CREATE=yes \
                TIMELINE_CLEANUP=yes \
                TIMELINE_MIN_AGE=1800 \
                TIMELINE_LIMIT_HOURLY=5 \
                TIMELINE_LIMIT_DAILY=7 \
                TIMELINE_LIMIT_WEEKLY=4 \
                TIMELINE_LIMIT_MONTHLY=3 \
                TIMELINE_LIMIT_YEARLY=0

            sudo snapper -c home set-config \
                NUMBER_CLEANUP=yes \
                NUMBER_MIN_AGE=1800 \
                NUMBER_LIMIT=30 \
                NUMBER_LIMIT_IMPORTANT=10

            # Allow user to list snapshots without sudo
            sudo snapper -c root set-config ALLOW_USERS=$USER
            sudo snapper -c home set-config ALLOW_USERS=$USER

            # Timers
            sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
            log_ok "Snapper: all configs and timers ready"

            # snap-pac config
            if [[ -f "$etc_dir/snap-pac/snap-pac.ini" ]]; then
                sudo cp "$etc_dir/snap-pac/snap-pac.ini" /etc/snap-pac.ini
                log_ok "Installed: /etc/snap-pac.ini"
            fi
        else
            log_info "Skipped Snapper configuration."
        fi
    fi
}

enable_services() {
    log_info "Enabling systemd user services..."

    # Kanata
    if [[ ${SELECTED[3]} -eq 1 ]] && [[ -f "$HOME/.config/systemd/user/kanata.service" ]]; then
        systemctl --user daemon-reload
        systemctl --user enable kanata.service 2>/dev/null && \
            log_ok "Enabled: kanata.service" || \
            log_warn "Could not enable kanata.service"
    fi

    # PipeWire (System category)
    if [[ ${SELECTED[7]} -eq 1 ]]; then
        for svc in pipewire.socket pipewire-pulse.socket wireplumber.service; do
            systemctl --user enable "$svc" 2>/dev/null && \
                log_ok "Enabled: $svc" || true
        done
    fi

    # GameMode (Gaming category)
    if [[ ${SELECTED[5]} -eq 1 ]]; then
        systemctl --user enable gamemoded.service 2>/dev/null && \
            log_ok "Enabled: gamemoded.service" || true
    fi

    # Docker (Development category)
    if [[ ${SELECTED[6]} -eq 1 ]] && command -v docker &>/dev/null; then
        sudo systemctl enable docker.service 2>/dev/null && \
            log_ok "Enabled: docker.service"
        if ! groups "$USER" | grep -q docker; then
            sudo usermod -aG docker "$USER" && \
                log_ok "Added $USER to docker group (re-login required)"
        else
            log_info "$USER is already in docker group."
        fi
    fi
}

install_fonts() {
    if [[ ${SELECTED[4]} -eq 1 ]] && [[ -d "$HOME/.local/share/fonts" ]]; then
        log_info "Refreshing font cache..."
        fc-cache -fv &>/dev/null
        log_ok "Font cache updated."
    fi
}

post_install_notes() {
    echo ""
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Post-Install Notes${NC}"
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════${NC}"
    echo ""

    if [[ ${SELECTED[8]} -eq 1 ]]; then
        echo -e "${YELLOW}  NVIDIA:${NC}"
        echo "    Add to kernel params: nvidia_drm.modeset=1"
        echo "    If using SDDM: sudo systemctl enable sddm"
        echo ""
    fi

    if [[ ${SELECTED[3]} -eq 1 ]]; then
        echo -e "${YELLOW}  Kanata (keyboard remapper):${NC}"
        echo "    sudo usermod -aG input,uinput \$USER"
        echo "    (Log out and back in for group changes to take effect)"
        echo ""
    fi

    if [[ ${SELECTED[9]} -eq 1 ]]; then
        echo -e "${YELLOW}  OpenRGB:${NC}"
        echo "    sudo udevadm control --reload-rules && sudo udevadm trigger"
        echo ""
    fi

    if [[ ${SELECTED[6]} -eq 1 ]]; then
        echo -e "${YELLOW}  Docker:${NC}"
        echo "    Re-login required for docker group to take effect."
        echo "    Test with: docker run hello-world"
        echo ""
    fi

    if [[ ${SELECTED[7]} -eq 1 ]]; then
        echo -e "${YELLOW}  System:${NC}"
        echo "    zram: Verify after reboot with 'swapon --show'"
        echo "    UFW: Check status with 'sudo ufw status'"
        echo ""
        echo -e "${YELLOW}  Snapper (Btrfs snapshots):${NC}"
        echo "    List snapshots:     btrfs-snapshots list"
        echo "    Create snapshot:    btrfs-snapshots create [root|home]"
        echo "    View changes:       btrfs-snapshots diff <number>"
        echo "    Rollback:           btrfs-snapshots rollback <number>"
        echo "    Manual rollback:    sudo snapper -c root undochange <num>..0"
        echo "    Note: systemd-boot does not support boot-from-snapshot."
        echo "          Rollback is done live via snapper undochange."
        echo ""
    fi

    echo -e "${YELLOW}  General:${NC}"
    echo "    Change default shell: chsh -s /usr/bin/fish"
    echo "    Reboot recommended after installation."
    echo ""
    echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
    echo ""
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

main() {
    clear
    banner
    check_prerequisites
    install_paru
    install_stow
    display_menu
    install_packages
    backup_configs
    stow_packages
    post_stow_fixes
    enable_services
    install_fonts
    post_install_notes
}

main "$@"
