# dotfiles

CachyOS + Hyprland rice with Catppuccin Mocha theme.

## System

| Component | Value |
|-----------|-------|
| OS | [CachyOS](https://cachyos.org/) (Arch-based) |
| WM | [Hyprland](https://hyprland.org/) |
| Bar | [Waybar](https://github.com/Alexays/Waybar) |
| Launcher | [Rofi](https://github.com/davatorium/rofi) (adi1090x themes) |
| Terminal | [Ghostty](https://ghostty.org/) |
| Shell | [Fish](https://fishshell.com/) + [Starship](https://starship.rs/) |
| Editor | [Neovim](https://neovim.io/) (LazyVim) — WebStorm as main IDE |
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
| `Hyper + Return` | Ghostty terminal |
| `Hyper + B` | Google Chrome |
| `Hyper + E` | Thunar (file manager) |
| `Hyper + C` | WebStorm |
| `Hyper + S` | Slack |
| `Hyper + N` | Notification center |
| `Hyper + P` | Screenshot (region select) |
| `Hyper + K` | Color picker |
| `Hyper + M` | YouTube Music |
| `Hyper + G` | Steam |
| `Hyper + D` | Discord |
| `Hyper + 1` | 1Password |
| `Hyper + L` | Lock screen |
| `Hyper + /` | Show keybinds |
| `Hyper + .` | Claude skills |
| `Hyper + ,` | Neovim keybinds cheatsheet |
| `Hyper + T` | Translate en↔es (rofi) |

### Windows

| Bind | Action |
|------|--------|
| `ALT + H/J/K/L` | Move focus (vim-style) |
| `ALT + Shift + H/J/K/L` | Move window |
| `ALT + Ctrl + H/J/K/L` | Resize window |
| `ALT + X` | Close window |
| `ALT + M` | Fullscreen |
| `ALT + F` | Toggle floating |
| `ALT + Mouse LMB` | Drag move |
| `ALT + Mouse RMB` | Drag resize |

### Workspaces (dual monitor 4+4)

```
Monitor LEFT (C52) — ALT+Q/W/E/R      Monitor RIGHT (B97) — ALT+U/I/O/P
  WS 1  󰈹 Browser  (boot)               WS 5  󰆍 Terminal  (boot)
  WS 2  󰝚 Music    (YT Music auto)      WS 6  󰨞 Code     (WebStorm auto)
  WS 3  󰙯 Chat     (Discord/Slack)      WS 7  󰭹 Misc
  WS 4  󰉋 Files                          WS 8  󰊗 Extra/Games
```

| Bind | Action |
|------|--------|
| `ALT + Q/W/E/R` | Switch workspace 1-4 (left monitor) |
| `ALT + U/I/O/P` | Switch workspace 5-8 (right monitor) |
| `ALT + Shift + Q/W/E/R` | Move window to WS 1-4 |
| `ALT + Shift + U/I/O/P` | Move window to WS 5-8 |
| `ALT + S` | Swap workspaces between monitors |
| `ALT + Tab` | Previous workspace (back and forth) |
| `ALT + `` ` `` ` | Toggle scratchpad |
| `ALT + Shift + `` ` `` ` | Move to scratchpad |

### Clipboard & Media

| Bind | Action |
|------|--------|
| `ALT + C` | Smart copy |
| `ALT + V` | Smart paste |
| `ALT + Shift + V` | Clipboard history (rofi) |
| `ALT + A` | Toggle audio output |
| `ALT + T` | Translate clipboard en↔es |

### Groups/Tabs

| Bind | Action |
|------|--------|
| `ALT + G` | Toggle group |
| `ALT + N` | Next in group |
| `ALT + Shift + N` | Previous in group |

### Keyboard Layout

| Bind | Action |
|------|--------|
| `Super + Space` | Switch US/ES layout |

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
ghostty     Ghostty terminal config
fish        Fish shell config
starship    Starship prompt config
zellij      Zellij multiplexer config
shell       .zshrc + .bashrc
kanata      Keyboard remapper + systemd service
swaync      Notification center
gtk         GTK-4.0 theme symlinks
kvantum     Qt5/Qt6 Kvantum theme
micro       Micro editor settings + colorschemes
nvim        Neovim (LazyVim) IDE — LSP, formatters, AI (Claude + Copilot)
gaming      GameMode, MangoHud, vkBasalt
git         Git config (delta, SSH signing via 1Password)
npm         npm config
claude      Claude Code config, rules, skills, agents, hooks
mimeapps    Default application associations
fonts       Custom font files
system-etc  System configs (NetworkManager, sysctl, udev, zram)
```

### Management

```bash
just stow [pkg...]     # Deploy packages (all if none specified)
just unstow <pkg...>   # Remove packages
just restow [pkg...]   # Re-deploy (unstow + stow)
just check [pkg...]    # Dry-run
just status            # Show which packages are deployed
just list              # List available packages
just install           # Run full installer
```

Or use the `dotf` Fish function:

```fish
dotf stow [pkg...]     # Deploy
dotf unstow <pkg...>   # Remove
dotf restow [pkg...]   # Re-deploy
dotf list              # List packages
dotf edit              # Open in $EDITOR
dotf check [pkg...]    # Dry-run
```

## Packages

The installer reads `packages.csv` and lets you pick categories:

| Category | Examples |
|----------|----------|
| core | Hyprland, Waybar, Rofi, SwayNC, hyprlock, hypridle, swww, cliphist |
| terminal | Ghostty, Neovim, Fish, Zsh, Starship, Zellij, zoxide, ripgrep, fzf |
| keyboard | Kanata |
| themes | Catppuccin (GTK, cursors, Kvantum), Papirus, Nerd Fonts |
| gaming | Steam, Lutris, GameMode, MangoHud, vkBasalt, Gamescope, Proton-GE |
| development | Git, delta, Rust, fnm, Docker, direnv, lazygit, just, 1Password CLI |
| system | PipeWire, NetworkManager, Bluetooth, btop, yazi, snapper, brightnessctl |
| nvidia | nvidia-dkms, nvidia-utils, libva-nvidia-driver, egl-wayland |
| hardware | OpenRGB, CoolerControl, liquidctl |
| browsers | Google Chrome |
| media | mpv, VLC, ffmpegthumbnailer |

## Shell Functions

Fish functions available after stowing `fish`:

| Function | Description |
|----------|-------------|
| `dotf` | Manage dotfiles with GNU Stow (stow, unstow, restow, list, edit, check) |
| `proj` | Quick project switcher — uses fzf to search `~/projects`, `~/work`, `~/dotfiles` |
| `opsync` | Load 1Password secrets into environment via `op inject` |

## Scripts

### Hyprland (`hypr/.config/hypr/scripts/`)

| Script | Description |
|--------|-------------|
| `audio-toggle.sh` | Switch between audio outputs (speakers/headphones) |
| `super-copy.sh` | Smart copy — detects context (terminal vs GUI) |
| `super-paste.sh` | Smart paste — detects context (terminal vs GUI) |
| `keybinds.sh` | Show keybinds cheatsheet in Rofi |
| `claude-skills.sh` | Show Claude Code skills cheatsheet in Rofi |
| `nvim-keys.sh` | Show Neovim/LazyVim keybindings cheatsheet in Rofi |
| `translate.sh` | Translate en↔es via rofi or clipboard (auto-detects language) |
| `reactive-rgb.sh` | Maps CPU temp to Catppuccin colors via OpenRGB (runs in background) |
| `wait-monitor.sh` | Monitor hotplug handler |

### Waybar (`waybar/.config/waybar/scripts/`)

| Script | Description |
|--------|-------------|
| `hw-monitor.sh` | Hardware monitoring (CPU, GPU, temps) for bar tooltip |
| `music-status.sh` | Music player status via playerctl |
| `music-toggle.sh` | Play/pause toggle via playerctl |
| `rofi-bluetooth.sh` | Bluetooth device manager in Rofi |
| `rofi-wifi.sh` | WiFi network manager in Rofi |

## Claude Code

The `claude` stow package deploys global config to `~/.claude/` (rules, skills, agents, hooks).

Project templates (Nuxt 4, Next.js 16) are **not** symlinked — use `claude-init` to copy them into a project:

```bash
claude-init nuxt4     # Copy Nuxt 4 config + shared tooling
claude-init next16    # Copy Next.js 16 config + shared tooling
```

This copies `.claude/CLAUDE.md`, `.claude/settings.json`, `.claude/project-scaffold.md`, and shared configs (biome, lefthook, commitlint, CI). Templates use **phased scaffolding** — each phase is executed one at a time.

MCP servers (Context7, Playwright, Sequential Thinking) are configured by `setup-mcp.sh`, which runs automatically during installation.

## Credits

- [adi1090x/rofi](https://github.com/adi1090x/rofi) - Rofi launcher themes
- [Catppuccin](https://github.com/catppuccin/catppuccin) - Color scheme
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) - Icon theme
