# Dotfiles de CachyOS + Hyprland

Configuración de los perfiles `workstation` y `desktop`, gestionada con GNU
Stow. Ambos reutilizan los mismos módulos comunes y solo separan el hardware de
Hyprland.

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
| Teclado | US/ES + Kanata |
| Navegador | qutebrowser + Brave como respaldo |
| Credenciales | 1Password CLI y agente SSH |

## Perfiles y módulos

Módulos compartidos:

```text
codex fish fonts ghostty git hypr-common kanata mimeapps noctalia
nvim qutebrowser shell starship vscode zellij
```

Cada perfil añade exactamente un módulo de hardware:

| Perfil | Módulo | Hardware |
|---|---|---|
| `workstation` | `hypr-laptop` | eDP, touchpad, entrada y brillo del portátil |
| `desktop` | `hypr-desktop` | dos Philips 273V7 por HDMI y entrada Keychron/Logitech |

El módulo Hyprland de `desktop` no configura touchpad ni teclas de brillo porque
el informe real de este equipo no detectó touchpad, batería interna ni
backlight. Los widgets adaptativos de Noctalia siguen compartidos y detectan los
dispositivos disponibles. GPU, CHWD, initramfs, arranque, Btrfs, ZRAM, `/etc` y
servicios quedan fuera de ambos perfiles.

Los paquetes del sistema y de AUR están declarados en `packages.csv`.

## Tema Project Atlas

La paleta `ProjectAtlas` genera los temas de Hyprland, GTK, Qt/KDE, Ghostty,
Kitty, Starship, btop, Zellij, Micro, bat/delta, Codex, Neovim, Orca y
VS Code/VSCodium.

`orca-safe-settings` actualiza con backup el tema de terminal de Orca antes de
abrir la aplicación; Hyprland lo ejecuta una vez al comenzar cada sesión.
1Password arranca de forma silenciosa después del `StatusNotifierWatcher` de
Noctalia y permanece accesible como icono inline en su bandeja.

## Instalación

```bash
git clone git@github.com:jesus-molano/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh workstation --check
./install.sh workstation

# Sobremesa inspeccionado (simular antes de aplicar)
./install.sh desktop --check
./install.sh desktop
```

El instalador usa Pacman y Shelly, comprueba los paquetes, simula Stow y guarda
una copia de los archivos que vaya a sustituir.

## Gestión

```bash
just list                  # módulos permitidos
just check workstation     # simulación del perfil completo
just check desktop         # simulación del perfil de sobremesa
just check hypr-desktop    # simulación de un módulo de hardware
just doctor                # diagnóstico; autodetecta el perfil desplegado
just doctor desktop        # diagnóstico explícito del sobremesa
just apply workstation     # simular y desplegar
just apply desktop         # simular y desplegar desktop
just remove workstation    # simular y retirar enlaces
```

Los módulos `hypr-common`, `hypr-laptop` y `hypr-desktop` se pueden comprobar
por separado, pero `just apply` obliga a usar un perfil completo. Para cambiar
de hardware, retira primero el perfil anterior y revisa la simulación del nuevo.

La configuración de `/etc` se gestiona por separado. Los módulos disponibles
son la regla udev de Kanata y el tema Project Atlas de SDDM:

```bash
just check-system udev
just apply-system udev
just check-system sddm
just apply-system sddm
```

## Teclado

Kanata convierte Caps Lock en:

- pulsación: `Esc`
- mantenida: `Hyper` (`Ctrl + Alt + Super + Shift`)
- salida de emergencia: `Ctrl + Space + Esc`

En el perfil `desktop`, el layout inicial es US para el Keychron ANSI y
`Super + Space` alterna entre US y español.

Los espacios del sobremesa se agrupan por mano: `Q/W/E/R` pertenecen a la
pantalla izquierda y `U/I/O/P` a la principal situada a la derecha. Q y U son
los espacios iniciales. Sus funciones son terminal, directorios, música, chat,
navegador, código, juegos y sistema, respectivamente.

La primera instalación de Kanata requiere cargar `uinput`, añadir el usuario al
grupo `input`, aplicar el módulo udev y habilitar el servicio. Usa Polkit y vuelve
a iniciar sesión para que systemd herede el grupo:

```bash
pkexec /usr/bin/modprobe uinput
pkexec /usr/bin/usermod -aG input "$USER"
just apply-system udev
systemctl --user daemon-reload
systemctl --user enable kanata.service
```

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
| `Super + Space` | Alternar teclado US/ES (`desktop`) |
| `Super + V` | Historial del portapapeles |

`Super` se limita al historial del portapapeles y al cambio de layout. El archivo
`hypr-common/.config/hypr/config/binds.lua` conserva además `Print`, el monitor
del sistema y las teclas físicas de calculadora y multimedia. Las teclas de
brillo viven solo en `hypr-laptop`.

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
(GitHub) y `yt` (YouTube); por ejemplo, `O aw qutebrowser`.

## Secretos

`with-secrets` ejecuta un comando con las referencias locales de 1Password:

```bash
with-secrets pnpm run deploy
```

## Validación

```bash
HYPR_PROFILE_DIR="$PWD/hypr-laptop/.config/hypr" \
  Hyprland --verify-config -c hypr-common/.config/hypr/hyprland.lua
HYPR_PROFILE_DIR="$PWD/hypr-desktop/.config/hypr" \
  Hyprland --verify-config -c hypr-common/.config/hypr/hyprland.lua
hyprctl configerrors
noctalia config validate noctalia/.config/noctalia/config.toml
kanata --check -c kanata/.config/kanata/config.kbd
just check workstation
just check desktop
git diff --check
```

## Rutas principales

```text
hypr-common/.config/hypr/       configuración compartida de Hyprland
hypr-laptop/.config/hypr/       hardware del portátil
hypr-desktop/.config/hypr/      hardware del sobremesa
noctalia/.config/noctalia/      Noctalia y paleta
kanata/.config/kanata/          teclado
ghostty/.config/ghostty/        terminal
fish/.config/fish/              shell y funciones
nvim/.config/nvim/              editor
vscode/                         VS Code y VSCodium
system-etc/                     archivos destinados a /etc
```

Orca se instala fuera de Pacman y debe proporcionar `orca-ide` en `PATH`.
