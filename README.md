# dotfiles

CachyOS + Hyprland rice with Catppuccin Mocha theme.

## System

| Component | Value |
|-----------|-------|
| OS | [CachyOS](https://cachyos.org/) (Arch-based) |
| WM | [Hyprland](https://hyprland.org/) |
| Bar | [Waybar](https://github.com/Alexays/Waybar) |
| Launcher | [Rofi](https://github.com/davatorium/rofi) (adi1090x themes) |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| Shell | [Fish](https://fishshell.com/) + [Starship](https://starship.rs/) |
| Multiplexer | [Zellij](https://zellij.dev/) |
| Notifications | [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| Theme | [Catppuccin Mocha](https://github.com/catppuccin/catppuccin) |
| Icons | [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) |
| Cursors | Catppuccin Mocha Dark |
| Font | JetBrains Mono Nerd Font |
| GPU | NVIDIA (nvidia-dkms) |
| Keyboard | [Kanata](https://github.com/jtroo/kanata) (Caps Lock = Hyper/Esc) |

## Keybinds

> `Hyper` = Caps Lock held (Ctrl+Alt+Super+Shift via Kanata). Tap = Esc.

### Apps

| Bind | Action |
|------|--------|
| `ALT + Space` | Rofi launcher |
| `Hyper + Return` | Kitty terminal |
| `Hyper + B` | Google Chrome |
| `Hyper + E` | Yazi (file manager) |
| `Hyper + C` | WebStorm |
| `Hyper + N` | Notification center |
| `Hyper + P` | Color picker |
| `Hyper + M` | Toggle MangoHud |

### Windows

| Bind | Action |
|------|--------|
| `ALT + H/J/K/L` | Move focus (vim-style) |
| `ALT + Shift + H/J/K/L` | Move window |
| `ALT + Ctrl + H/J/K/L` | Resize window |
| `ALT + W` | Close window |
| `ALT + M` | Fullscreen |
| `ALT + F` | Toggle floating |
| `ALT + Mouse LMB` | Drag move |
| `ALT + Mouse RMB` | Drag resize |

### Workspaces

| Bind | Action |
|------|--------|
| `ALT + 1-6` | Switch workspace |
| `ALT + Shift + 1-6` | Move window to workspace |

### Clipboard & Media

| Bind | Action |
|------|--------|
| `ALT + C` | Smart copy |
| `ALT + V` | Smart paste |
| `ALT + Shift + V` | Clipboard history (rofi) |
| `ALT + A` | Toggle audio output |
| `Hyper + S` | Screenshot (region select) |

### Keyboard Layout

| Bind | Action |
|------|--------|
| `ALT + Ctrl + Space` | Switch US/ES layout |

## Installation

```bash
git clone https://github.com/jesus-molano/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

The interactive installer will:
1. Install `paru` (AUR helper) if missing
2. Install `stow` if missing
3. Let you select package categories to install
4. Install packages via `paru`
5. Back up existing configs to `~/.config-backup-<timestamp>/`
6. Deploy dotfiles via GNU Stow
7. Enable systemd services
8. Refresh font cache

### Manual Post-Install Steps

- **NVIDIA kernel params**: Add `nvidia_drm.modeset=1` to your bootloader
- **Default shell**: `chsh -s /usr/bin/fish`
- **Kanata permissions**: `sudo usermod -aG input,uinput $USER`
- **OpenRGB udev rules**: `sudo udevadm control --reload-rules && sudo udevadm trigger`
- **SDDM theme**: Configure via `/etc/sddm.conf.d/`

## Stow Packages

```
hypr        Hyprland config + scripts
waybar      Status bar config + scripts
rofi        Rofi launcher (adi1090x themes)
kitty       Kitty terminal config
fish        Fish shell config
starship    Starship prompt config
zellij      Zellij multiplexer config
shell       .zshrc + .bashrc
kanata      Keyboard remapper + systemd service
swaync      Notification center
gtk         GTK-4.0 theme symlinks
kvantum     Qt5/Qt6 Kvantum theme
micro       Micro editor settings + colorschemes
gaming      GameMode, MangoHud, vkBasalt
git         Git config
npm         npm config
mimeapps    Default application associations
fonts       Custom font files
```

To stow/unstow individual packages:

```bash
cd ~/dotfiles
stow <package>      # deploy
stow -D <package>   # remove
```

## Credits

- [adi1090x/rofi](https://github.com/adi1090x/rofi) - Rofi launcher themes
- [Catppuccin](https://github.com/catppuccin/catppuccin) - Color scheme
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) - Icon theme
