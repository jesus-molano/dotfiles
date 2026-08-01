# CachyOS Acer Aspire VX dotfiles

Configuración personal y reproducible para CachyOS, Hyprland Lua y Noctalia v5
en un Acer Aspire VX5-591G con pantalla interna `eDP-1`.

## Perfil actual

| Componente | Elección |
|---|---|
| Shell de escritorio | Noctalia v5 (barra, launcher, paneles, avisos y bloqueo) |
| Compositor | Hyprland Lua sobre la base mantenida por CachyOS |
| Terminal | Ghostty |
| Shell | Fish + Starship + Zoxide |
| Archivos | Dolphin principal; Thunar como alternativa ligera |
| Editor | Neovim/LazyVim |
| Multiplexor | Zellij |
| IA | Codex; Claude se retiró del repositorio |
| Credenciales | 1Password y `gh` |
| Teclado | Español; Caps al tocar = Esc, mantenida = Hyper |
| GPU | Intel + NVIDIA Pascal mediante el perfil PRIME 580xx de `chwd` |

No se instalan Steam, Lutris, Discord, WebStorm, Docker, Waybar, Rofi ni SwayNC.
El instalador tampoco modifica GPU, initramfs, arranque, Btrfs, Snapper, zram o
firewall: esos elementos se inspeccionan y mantienen con las herramientas de
CachyOS.

## Teclado y ventanas

`Hyper` significa mantener Caps Lock (`Ctrl+Alt+Super+Shift`). Tocar Caps sigue
enviando Escape. El corte de emergencia de Kanata es `Ctrl+Space+Esc`.

| Atajo | Acción |
|---|---|
| `Alt + H/J/K/L` | Mover el foco |
| `Alt + Shift + H/J/K/L` | Mover la ventana |
| `Alt + Ctrl + H/J/K/L` | Redimensionar |
| `Alt + Q/W/E/R/U/I/O/P` | Espacios 1–8 en la pantalla actual |
| `Alt + Shift + Q/W/E/R/U/I/O/P` | Enviar ventana al espacio |
| `Alt + Tab` | Selector de ventanas de Noctalia |
| `Alt + X` | Cerrar ventana |
| `Alt + M` | Pantalla completa |
| `Alt + F` | Flotante |
| `Alt + G / N / Shift+N` | Crear grupo / pestaña siguiente / anterior |

## Capa Hyper

| Atajo | Acción |
|---|---|
| `Hyper + Enter` | Ghostty |
| `Hyper + B` | Brave |
| `Hyper + E` | Dolphin |
| `Hyper + Shift + E` | Thunar |
| `Hyper + .` | Codex en Ghostty |
| `Hyper + 1` | 1Password |
| `Hyper + N` | Notificaciones |
| `Hyper + P` | Captura de región |
| `Hyper + Q` | Menú de sesión |
| `Hyper + L` | Bloquear |
| `Hyper + K` | Selector de color |

## Noctalia

La configuración declarativa está en `noctalia/.config/noctalia/config.toml`.
La barra compacta para portátil incluye espacios, reloj, multimedia, privacidad,
bandeja, avisos, red, Bluetooth, volumen, brillo, perfil energético y batería.
No sondea la GPU dedicada. Noctalia recarga TOML automáticamente.

Validación:

```bash
noctalia config validate noctalia/.config/noctalia/config.toml
```

Los cambios hechos desde la interfaz se guardan en
`~/.local/state/noctalia/settings.toml` y tienen prioridad sobre los dotfiles.
Para llevarlos al repositorio, exporta la configuración combinada y revísala:

```bash
noctalia config export > /tmp/noctalia-user.toml
```

## Instalación

El instalador empieza con todas las categorías desmarcadas, usa Shelly para AUR,
simula Stow antes de escribir y crea una copia reversible. No usa Paru ni aplica
ajustes delicados del sistema.

```bash
git clone git@github.com:jesus-molano/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Los módulos principales de este portátil son:

```text
hypr-laptop noctalia kanata ghostty fish starship zellij nvim
git codex mimeapps fonts gtk kvantum micro
```

Gestión manual:

```bash
just check hypr-laptop noctalia kanata
just restow hypr-laptop noctalia kanata
just status
```

Stow se ejecuta con `--no-folding` donde importa para no convertir directorios
dinámicos como `~/.codex` o `~/.config/hypr` en un único enlace.

## Comprobaciones

```bash
Hyprland --verify-config
hyprctl reload
hyprctl configerrors
noctalia config validate
kanata --check -c ~/.config/kanata/config.kbd
systemctl --failed
systemctl --user --failed
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

La guía de instalación y recuperación que originó esta migración está en el
medio Ventoy del equipo. El estado real del portátil prevalece siempre sobre
los comandos históricos de esa guía.
