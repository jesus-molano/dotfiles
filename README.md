# Dotfiles de CachyOS + Hyprland

Configuración del perfil `workstation`, gestionada con GNU Stow.

## Stack

| Componente | Configuración |
|---|---|
| Compositor | Hyprland Lua |
| Shell de escritorio | Noctalia v5 |
| Terminal | Ghostty |
| Shell | Fish + Starship + Zoxide |
| Archivos | Dolphin |
| Editor | Neovim/LazyVim |
| Multiplexor | Zellij |
| Teclado | Español + Kanata |
| Navegador | qutebrowser + Brave como respaldo |
| Credenciales | 1Password CLI y agente SSH |

## Módulos

El perfil `workstation` despliega estos módulos:

```text
codex fish fonts ghostty git hypr-laptop kanata mimeapps noctalia
nvim qutebrowser shell starship vscode zellij
```

Los paquetes del sistema y de AUR están declarados en `packages.csv`.

## Tema Project Atlas

La paleta `ProjectAtlas` genera los temas de Hyprland, GTK, Qt/KDE, Ghostty,
Kitty, Starship, btop, Zellij, Micro, bat/delta, Codex, Neovim, Orca y
VS Code/VSCodium.

## Instalación

```bash
git clone git@github.com:jesus-molano/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh workstation --check
./install.sh workstation
```

El instalador usa Pacman y Shelly, comprueba los paquetes, simula Stow y guarda
una copia de los archivos que vaya a sustituir.

## Gestión

```bash
just list                  # módulos permitidos
just check workstation     # simulación del perfil completo
just check hypr-laptop     # simulación de un módulo
just doctor                # diagnóstico completo de solo lectura
just apply workstation     # simular y desplegar
just remove workstation    # simular y retirar enlaces
```

La configuración de `/etc` se gestiona por separado. El módulo disponible es
la regla udev de Kanata:

```bash
just check-system udev
just apply-system udev
```

## Teclado

Kanata convierte Caps Lock en:

- pulsación: `Esc`
- mantenida: `Hyper` (`Ctrl + Alt + Super + Shift`)
- salida de emergencia: `Ctrl + Space + Esc`

## Atajos

### Ventanas y espacios

| Atajo | Acción |
|---|---|
| `Alt + H/J/K/L` | Mover el foco |
| `Alt + Shift + H/J/K/L` | Mover la ventana |
| `Alt + Ctrl + H/J/K/L` | Redimensionar la ventana |
| `Alt + Q/W/E/R/U/I/O/P` | Ir a los espacios 1–8 |
| `Alt + Shift + Q/W/E/R/U/I/O/P` | Enviar la ventana a un espacio |
| `Alt + Tab` | Selector de ventanas |
| `Alt + X` | Cerrar la ventana activa |
| `Alt + M` | Maximizar |
| `Alt + F` | Alternar flotante |
| `Hyper + D` | Alternar la dirección de la división |
| `Hyper + F` | Alternar pantalla completa |
| `Alt + S` | Mostrar u ocultar el scratchpad |
| `Alt + Shift + S` | Enviar al scratchpad |
| `Alt + G` | Alternar grupo de ventanas |
| `Alt + N` / `Alt + Shift + N` | Recorrer ventanas del grupo |

### Aplicaciones y sistema

| Atajo | Acción |
|---|---|
| `Hyper + Enter` | Ghostty |
| `Hyper + B` | qutebrowser |
| `Hyper + E` | Dolphin |
| `Hyper + O` | Enfocar o abrir Orca |
| `Hyper + M` | Enfocar o abrir Spotify |
| `Hyper + 1` | 1Password |
| `Alt + Space` | Launcher de Noctalia |
| `Hyper + N` | Notificaciones |
| `Hyper + P` | Captura de región |
| `Hyper + K` | Selector de color |
| `Hyper + C` | Cafeína |
| `Hyper + L` | Bloquear la sesión |
| `Hyper + Q` | Menú de sesión |
| `Hyper + 7` | Ayuda de atajos |
| `Super + V` | Historial del portapapeles |

`Super` queda reservado para el historial del portapapeles. El archivo
`hypr-laptop/.config/hypr/config/binds.lua` conserva además `Print`, el monitor
del sistema y las teclas físicas de calculadora, multimedia y brillo.

### qutebrowser

La configuración usa la paleta Project Atlas, navegación Vim y bloqueo ABP +
hosts. Además de los atajos nativos (`f`, `F`, `o`, `t`, `J`, `K`, `d`, `u`):

| Atajo | Acción |
|---|---|
| `,a` | Alternar el bloqueo temporalmente para el dominio actual |
| `,A` | Alternar el bloqueo globalmente durante la sesión |
| `,u` | Actualizar todas las listas de bloqueo |
| `,B` | Abrir la página actual en Brave |
| `;B` | Elegir mediante hints un enlace para abrirlo en Brave |
| `,e` | Editar la configuración en Neovim |
| `,r` | Recargar la configuración |

Los buscadores rápidos disponibles son `aw` (ArchWiki), `g` (Google), `gh`
(GitHub) y `yt` (YouTube); por ejemplo, `t aw qutebrowser`.

## Secretos

`with-secrets` ejecuta un comando con las referencias locales de 1Password:

```bash
with-secrets pnpm run deploy
```

## Validación

```bash
Hyprland --verify-config
hyprctl configerrors
noctalia config validate noctalia/.config/noctalia/config.toml
kanata --check -c kanata/.config/kanata/config.kbd
just check workstation
git diff --check
```

## Rutas principales

```text
hypr-laptop/.config/hypr/       Hyprland Lua
noctalia/.config/noctalia/      Noctalia y paleta
kanata/.config/kanata/          teclado
ghostty/.config/ghostty/        terminal
fish/.config/fish/              shell y funciones
nvim/.config/nvim/              editor
vscode/                         VS Code y VSCodium
system-etc/                     archivos destinados a /etc
```

Orca se instala fuera de Pacman y debe proporcionar `orca-ide` en `PATH`.
