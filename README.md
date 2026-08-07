# Dotfiles de CachyOS + Hyprland

Configuración de los perfiles `workstation` y `desktop`, gestionada con GNU
Stow. Ambos reutilizan los mismos módulos comunes; `desktop` añade su hardware y
el perfil gaming, mientras `workstation` conserva la configuración del portátil.

## Stack

| Componente | Configuración |
|---|---|
| Compositor | Hyprland Lua |
| Shell de escritorio | Noctalia v5 |
| Terminal | Ghostty + Fish, Yazi y Television |
| Shell | Fish + Starship + Zoxide + Atuin |
| Archivos | Dolphin |
| Editor | Neovim/LazyVim |
| Multiplexor | Zellij |
| Teclado | US/ES + Kanata |
| Navegador | qutebrowser + Brave como respaldo |
| Aplicaciones comunes | Spotify, LocalSend, Micro, calculadora y Stremio (`flathub/stable`) |
| Credenciales | 1Password CLI y agente SSH |
| Toolchain | mise, pnpm, uv, Ruff, Difftastic, watchexec e hyperfine |
| Gaming (`desktop`) | Steam, Heroic, Lutris, Faugus, ProtonPlus, Gamescope, MangoHud y benchmarker CachyOS |
| Backup (`desktop`) | Ludusavi + Restic + rclone, con timers desactivados por defecto |

## Perfiles y módulos

Módulos compartidos:

```text
codex fish fonts ghostty git hypr-common kanata mimeapps noctalia
nvim qutebrowser shell starship vscode zellij
```

Cada perfil añade sus módulos específicos:

| Perfil | Módulos | Hardware |
|---|---|---|
| `workstation` | `hypr-laptop` | eDP, touchpad, entrada y brillo del portátil |
| `desktop` | `hypr-desktop gaming backup` | uno o dos Philips 273V7 a 74.97 Hz, RTX 3060 Ti y entrada Keychron/Logitech |

El módulo Hyprland de `desktop` no configura touchpad ni teclas de brillo porque
el informe real de este equipo no detectó touchpad, batería interna ni
backlight. Los widgets adaptativos de Noctalia siguen compartidos y detectan los
dispositivos disponibles. GPU, CHWD, initramfs, arranque, Btrfs, ZRAM, `/etc` y
servicios quedan fuera de ambos perfiles.

`gaming` y `backup` son exclusivos del sobremesa y solo gestionan archivos en
`HOME`. CHWD continúa siendo el propietario del controlador NVIDIA.

La arquitectura completa está documentada en [PROFILES.md](PROFILES.md).
`profiles.sh` es la fuente única de módulos; `packages.csv` declara paquetes
Pacman/AUR con ámbito explícito y `flatpaks.csv` junto a
`flatpak-remotes.csv` declara las aplicaciones Flatpak y su procedencia.

## Tema Project Atlas

La paleta `ProjectAtlas` genera los temas de Hyprland, GTK, Qt/KDE, Ghostty,
Kitty, Starship, btop, Zellij, Micro, bat/delta, Codex, Neovim, Orca y
VS Code/VSCodium.

`orca-safe-settings` actualiza con backup el tema de terminal de Orca antes de
abrir la aplicación; Hyprland lo ejecuta una vez al comenzar cada sesión.
1Password arranca de forma silenciosa después del `StatusNotifierWatcher` de
Noctalia y permanece accesible como icono inline en su bandeja.

## Instalación paso a paso

Ejecuta todo como tu usuario normal, nunca como `root`. Elige un único perfil:

- `workstation`: portátil, sin paquetes ni configuración gaming;
- `desktop`: sobremesa inspeccionado, dos monitores y perfil gaming completo.

### 1. Preparar CachyOS

El instalador necesita Git, GNU Stow, Shelly y, para los atajos de gestión,
Just. En una instalación nueva de CachyOS:

```bash
pkexec /usr/bin/shelly install standard --no-confirm git base-devel stow just
```

Si la imagen instalada aún no incluye Shelly, usa Pacman una sola vez mediante
el diálogo gráfico de Polkit:

```bash
pkexec /usr/bin/pacman -S --needed shelly git base-devel stow just
```

No instales manualmente otro controlador NVIDIA: CHWD conserva su propiedad.

### 2. Obtener la rama canónica

Instalación nueva mediante SSH (requiere que la clave de GitHub ya funcione):

```bash
git clone --branch main git@github.com:jesus-molano/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
git status --short --branch
```

Si prefieres HTTPS y tu cuenta tiene acceso al repositorio:

```bash
git clone --branch main https://github.com/jesus-molano/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
git status --short --branch
```

Si `~/.dotfiles` ya existe, conserva primero cualquier cambio local y actualiza
solo una copia limpia de `main`:

```bash
cd ~/.dotfiles
git status --short --branch
git switch main
git pull --ff-only
```

No borres ni sobrescribas una copia existente para forzar la actualización.

### 3. Inspeccionar antes de modificar

Para el sobremesa:

```bash
just list
just packages desktop
./install.sh desktop --check
```

Para el portátil, sustituye `desktop` por `workstation`. `--check` valida los
manifiestos y la disponibilidad de paquetes nativos y Flatpak cuando el remoto
ya existe, muestra los paquetes AUR para revisión y después simula Stow sin
instalar ni escribir en `HOME`. Revisa
especialmente cualquier línea `BACKUP:`: identifica un archivo existente que el
despliegue moverá a una copia de seguridad. La disponibilidad AUR se confirma al
aplicar, cuando Shelly presenta su procedencia antes de cada instalación.

`just check desktop` y `just check workstation` permiten repetir únicamente la
simulación de Stow, sin consultar los repositorios de paquetes.

### 4. Aplicar el perfil completo

Después de revisar una simulación limpia:

```bash
just apply desktop
```

Para el portátil usa `just apply workstation`. El comando vuelve a mostrar el
perfil y el destino, espera una confirmación `s`, instala solo los paquetes que
falten mediante Shelly —con diálogo Polkit para los nativos—, añade los remotos
y aplicaciones Flatpak declarados para el usuario, crea la copia
reversible de los conflictos en `HOME` y finalmente ejecuta Stow. Los paquetes
AUR se compilan como usuario y Shelly puede solicitar `sudo` únicamente al
instalar el artefacto construido; elevar toda la compilación no es apropiado.
También se puede invocar directamente como `./install.sh desktop`. La
transacción de paquetes modifica el sistema global y no se revierte mediante el
backup de Stow. Las aplicaciones Flatpak tampoco forman parte de ese backup;
su rollback exacto está documentado en [PROFILES.md](PROFILES.md).

Cuando existen conflictos en `HOME`, sus backups se guardan bajo:

```text
~/.local/state/dotfiles/backups/<perfil>-<fecha>/
```

Si Stow falla, el instalador intenta restaurar automáticamente los destinos que
acababa de respaldar.

### 5. Cerrar sesión y validar

Cierra la sesión y vuelve a entrar para que systemd y las aplicaciones reciban
el entorno nuevo —incluida la caché de shaders del perfil gaming—. Después:

```bash
just doctor desktop
hyprctl configerrors
```

En el portátil usa `just doctor workstation`. El doctor es de solo lectura y
distingue entre errores, avisos y dispositivos opcionales ausentes, como un
DualSense desconectado. La configuración de Kanata que requiere `/etc` se aplica
por separado siguiendo la sección [Teclado](#teclado).

La secuencia completa de cada perfil queda, por tanto:

| Acción | Portátil | Sobremesa |
|---|---|---|
| Ver paquetes | `just packages workstation` | `just packages desktop` |
| Simular | `./install.sh workstation --check` | `./install.sh desktop --check` |
| Aplicar | `just apply workstation` | `just apply desktop` |
| Diagnosticar | `just doctor workstation` | `just doctor desktop` |

### Qué cambia y qué queda fuera

El instalador gestiona paquetes globales, aplicaciones Flatpak del usuario y
enlaces en `HOME`. No despliega
`system-etc`, no cambia explícitamente el controlador NVIDIA, CHWD, initramfs,
arranque, Btrfs, ZRAM o firmware, ni habilita servicios. Pacman/Shelly sí pueden
instalar archivos, hooks o unidades proporcionados por sus paquetes; esa parte
no queda cubierta por el backup de `HOME`. El perfil tampoco mueve o borra
bibliotecas de juegos. Los módulos propios de `/etc` siempre requieren los
comandos y la confirmación explícita de su sección.

### Cambiar de perfil

Retira primero los enlaces del perfil anterior, simula el nuevo y solo entonces
aplícalo. Por ejemplo, para pasar del portátil al sobremesa:

```bash
just remove workstation
./install.sh desktop --check
just apply desktop
```

La retirada no desinstala paquetes ni elimina datos personales. Para el cambio
inverso usa `just remove desktop` y después valida y aplica `workstation`.

## Gestión

```bash
just list                  # módulos permitidos
just packages desktop      # paquetes y app IDs efectivos, sin modificar nada
just lint desktop          # validación hermética de la rama
just plan desktop          # simulación contra el HOME real
just check workstation     # simulación del perfil completo
just check desktop         # simulación del perfil de sobremesa
just check gaming          # simulación aislada de los dotfiles gaming
just check hypr-desktop    # simulación de un módulo de hardware
just doctor                # diagnóstico; autodetecta el perfil desplegado
just doctor desktop        # diagnóstico explícito del sobremesa
just doctor-live desktop   # solo estado del host ya desplegado
just apply workstation     # simular y desplegar
just apply desktop         # simular y desplegar desktop
just remove workstation    # simular y retirar enlaces
just remove gaming         # retirar solo enlaces gaming, nunca datos de juegos
```

`dotf status` también exige el perfil (`dotf status desktop` o
`dotf status workstation`) para no asumir el hardware del equipo actual.

Los módulos `hypr-common`, `hypr-laptop` y `hypr-desktop` se pueden comprobar
por separado, pero `just apply` obliga a usar un perfil completo. Para cambiar
de hardware, retira primero el perfil anterior y revisa la simulación del nuevo.

La configuración de `/etc` se gestiona por separado. Los módulos disponibles
son la regla udev de Kanata, el tema Project Atlas de SDDM y la retención
acotada de Snapper para `root`:

```bash
just check-system udev
just apply-system udev
just check-system sddm
just apply-system sddm
just check-system snapper
just apply-system snapper
just check-system systemd       # automount de /mnt/backups en desktop
just apply-system systemd
```

El último comando muestra la diferencia, identifica `/etc/snapper/configs/root`
como destino y crea una copia antes de sustituirlo. Los servicios siguen una
guarda distinta: `just check-maintenance` no escribe y `just apply-maintenance`
activa únicamente `btrfs-scrub@-.timer` y `smartd.service` tras confirmar su
nombre. El rollback se imprime antes de aplicar.

## Teclado

Kanata convierte Caps Lock en:

- pulsación: `Esc`
- mantenida: `Hyper` (`Ctrl + Alt + Super + Shift`)
- salida de emergencia: `Ctrl + Space + Esc`

En el perfil `desktop`, el layout inicial es US para el Keychron ANSI y
`Super + Space` alterna entre US y español.

Con los dos monitores conectados, los espacios del sobremesa se agrupan por
mano: `Q/W/E/R` pertenecen a la pantalla izquierda y `U/I/O/P` a la principal
situada a la derecha. Q y U son los espacios iniciales. Si solo permanece
`HDMI-A-1` o `HDMI-A-2`, los ocho espacios persistentes se muestran en esa
pantalla. Hyprland recalcula la distribución al conectar o desconectar una
salida, sin cambiar los atajos. En el desktop sus funciones son terminal,
archivos, música, comunicación, navegador, código, juegos y miscelánea. El
workspace 6 (`I`, código) usa el layout `scrolling`: `Hyper + ,/.` cambia de
columna y `Hyper + ;` recorre anchos 1/3, 1/2, 2/3 y completo.

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

## Gaming

El perfil `desktop` instala el runtime de CachyOS y los launchers Steam, Heroic,
Lutris y Faugus. `game-run` aplica `game-performance` y permite activar MangoHud
o una superficie Gamescope de 1920x1080 a 75 Hz por juego:

```bash
game-run -- juego
game-run --hud -- juego
game-run --gamescope --hud -- juego
game-run --dlss --hud -- juego

# Opciones de lanzamiento de Steam
game-run -- %command%

# Arma Reforger en este desktop: evita el fallo de follaje en Linux/NVIDIA
VKD3D_SWAPCHAIN_LATENCY_FRAMES=1 game-run -- %command%
```

Steam conserva Proton oficial de Valve como valor global; Proton-CachyOS SLR se
elige solo para el título que lo necesite. Las bibliotecas deben permanecer en
el NVMe Btrfs y no en NTFS. El DualSense es opcional y el soporte anti-cheat
depende del publisher. La auditoría de ReBAR y DOCP se documenta, pero no cambia
firmware ni configuración de sistema.

Consulta [GAMING.md](GAMING.md) para launchers, almacenamiento, diagnóstico,
rollback seguro, limitaciones y fuentes.

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
| `Hyper + Y` | Yazi en Ghostty |
| `Hyper + O` | Enfocar o abrir Orca |
| `Hyper + M` | Enfocar o abrir Spotify |
| `Hyper + G` | Enfocar o abrir Steam (`desktop`) |
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
| `,p` | Abrir una ventana de navegación privada |
| `,B` | Abrir la página actual en Brave |
| `;B` | Elegir mediante hints un enlace para abrirlo en Brave |
| `,e` | Editar la configuración en Neovim |
| `,r` | Recargar la configuración |

Los buscadores rápidos disponibles son `aw` (ArchWiki), `g` (Google), `gh`
(GitHub) y `yt` (YouTube); por ejemplo, `O aw qutebrowser`.

El launcher admite proveedores persistentes: `/proj` registra un repositorio en
Orca o abre Ghostty en su directorio, `/ssh` abre un alias de `~/.ssh/config`,
`/game` reúne launchers y SCX Manager solo en `desktop`, y `/cmd` ofrece
acciones locales acotadas. Las rutas nunca se interpolan directamente en el
shell: el proveedor solo entrega identificadores que `desktop-launcher` vuelve
a resolver.

## Secretos

`with-secrets` ejecuta un comando con las referencias locales de 1Password sin
exportarlas a la sesión padre. No lee un `.env` con valores: `~/.env.op` contiene
solo referencias `op://` y nunca se versiona.

```bash
with-secrets pnpm run deploy
```

### Backup cifrado del desktop

El módulo `backup` prepara Ludusavi, Restic y rclone, pero no inventa un destino
remoto ni habilita timers. Crea primero un ítem de 1Password con la URL de
repositorio Restic y su contraseña; después copia la plantilla y sustituye solo
los nombres de referencia:

```bash
install -m 600 .env.op.example ~/.env.op
micro ~/.env.op
desktop-backup-init
desktop-backup
desktop-backup-credential-init
just apply-user-timers
```

`desktop-backup-init` muestra el destino de forma oculta y exige
`INICIALIZAR`. El backup diario guarda el canario, documentos/proyectos,
dotfiles y el staging de partidas de Ludusavi; omite cachés, dependencias y
objetos Git. La retención es 7 diarios, 5 semanales y 12 mensuales. Cada mes se
ejecutan `restic check --read-data-subset=5%`, `prune` y una restauración del
canario. `desktop-backup-credential-init` convierte la contraseña inyectada por
1Password en una credencial cifrada y ligada al usuario/equipo mediante
`systemd-creds`; los timers la descifran solo dentro de cada unidad, por lo que
no dependen de que 1Password esté desbloqueado de madrugada. Ningún timer se
habilita durante Stow.
La retención y `restore latest` quedan además acotados al hostname que creó el
snapshot, incluso si varios equipos comparten el mismo repositorio.

Revisa el estado con:

```bash
just check-user-timers
systemctl --user status restic-backup.service restic-maintenance.service
```

### Toolchain y shell

`mise` fija Node 26.5.1, `uv` y Ruff cubren Python, y Atuin reemplaza la búsqueda
de historial sin sincronización ni IA. Su filtro excluye comandos con
`with-secrets`, `op`, contraseñas, tokens o claves. Tras desplegar esta rama,
migra Atlas fuera de `fnm` en una transacción separada:

Fish detecta el Android SDK local en `~/.local/share/android-sdk`, exporta
`ANDROID_HOME`, `ANDROID_SDK_ROOT` y `ANDROID_AVD_HOME`, y añade
`platform-tools` y `cmdline-tools/latest/bin` al `PATH`. El perfil `desktop`
publica las mismas rutas Android en la sesión gráfica para Orca.

```bash
just toolchain-check
just toolchain-migrate
just atlas-check
```

La migración valida primero el Node de mise, retira solo el paquete `fnm`,
reregistra `[mcp_servers.component-atlas]` y trata de reinstalar `fnm` si la
validación final falla.

Yazi queda integrado como función `y`: al salir cambia Fish al directorio
seleccionado. Television se prueba con `tv`, `tvg` (repositorios Git) y `tvt`
(contenido), sin apropiarse de `Ctrl + R`, que continúa siendo de Atuin.
Delta conserva el `git diff` lineal y Difftastic queda disponible bajo demanda
con `git dft`, `git dshow`, `git dlog` o `git difftool`.

### Codex y Orca

El repositorio añade un revisor Linux de solo lectura, la skill local
`$cachyos-host-audit` y el flujo de ingeniería formado por
`systematic-debugging`, `test-driven-development` y
`verification-before-completion`. También incorpora reglas de auditoría
estrechas y notificaciones que nunca incluyen el prompt ni la respuesta. La
configuración viva se fusiona para conservar trusts, hooks de Orca y MCP:

```bash
just codex-check
just codex-sync
just codex-clean-rules
```

La sincronización activa también `features.memories`. Es memoria auxiliar local
generada por Codex; `AGENTS.md` continúa siendo la fuente canónica de
instrucciones y el estado generado bajo `~/.codex/memories` no se versiona.

Las tres automatizaciones de Orca creadas para este host —auditoría semanal,
radar upstream y auditoría mensual Restic— nacen desactivadas. Revísalas con
`orca automations list --json` antes de habilitar cualquiera desde Orca.

### Escritorio y captura

Noctalia usa un horario privado local para luz nocturna, brillo DDC/CI para los
dos Philips y el plugin oficial `noctalia/screen_recorder`. Este se materializa
desde la fuente oficial al arrancar la configuración desplegada y usa
`gpu-screen-recorder`: 1080p60 H.264, audio de salida y replay de 90 segundos en
RAM. El acceso está en el centro de control. No se ejecuta `hyprsunset` en
paralelo. La cápsula de recursos muestra uso de CPU, temperatura de CPU, RAM y
temperatura de la GPU; las temperaturas se actualizan cada tres segundos.
`start-noctalia-ready` retrasa como mínimo tres segundos el inicio de la shell y
espera hasta veinte segundos a que todas las salidas externas activas aparezcan
en DDC; evita que uno de dos monitores idénticos quede marcado como deshabilitado
por una carrera de detección durante el arranque.

En el perfil `desktop`, `ensure-main-hdmi-audio` selecciona al iniciar el primer
perfil HDMI de la NVIDIA (`hdmi-stereo`), que corresponde al Philips principal
de la derecha. Ese monitor aporta el jack de audio; el perfil `hdmi-stereo-extra1`
del Philips izquierdo no se usa como salida predeterminada. El helper espera a
PipeWire durante un máximo de veinte segundos y mueve también las aplicaciones
que hayan abierto un stream antes de que aparezca el monitor.

## Validación

```bash
just lint desktop
just lint workstation
./install.sh desktop --list-packages
./install.sh workstation --list-packages
HYPR_PROFILE_DIR="$PWD/hypr-laptop/.config/hypr" \
  Hyprland --verify-config -c hypr-common/.config/hypr/hyprland.lua
HYPR_PROFILE_DIR="$PWD/hypr-desktop/.config/hypr" \
  Hyprland --verify-config -c hypr-common/.config/hypr/hyprland.lua
hyprctl configerrors
noctalia config validate noctalia/.config/noctalia/config.toml
kanata --check -c kanata/.config/kanata/config.kbd
just check desktop
just check gaming
just doctor desktop
just doctor-live desktop
git diff --check
```

## Rutas principales

```text
hypr-common/.config/hypr/       configuración compartida de Hyprland
profiles.sh                     composición canónica de módulos Stow
packages.csv                    paquetes Pacman/AUR por ámbito
flatpaks.csv                    aplicaciones Flatpak por remoto y rama
flatpak-remotes.csv             URLs canónicas de remotos Flatpak
hypr-laptop/.config/hypr/       hardware del portátil
hypr-desktop/.config/hypr/      hardware del sobremesa
gaming/                         wrappers y configuración gaming del sobremesa
backup/                         Restic, Ludusavi y timers de usuario del sobremesa
noctalia/.config/noctalia/      Noctalia y paleta
kanata/.config/kanata/          teclado
ghostty/.config/ghostty/        terminal
fish/.config/fish/              shell y funciones
nvim/.config/nvim/              editor
vscode/                         VS Code y VSCodium
system-etc/                     archivos destinados a /etc
```

Orca se instala fuera de Pacman y debe proporcionar `orca-ide` en `PATH`.
