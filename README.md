# Dotfiles de CachyOS + Hyprland

Configuración portable de CachyOS, Hyprland y Noctalia gestionada con GNU Stow.
Cada instalación se compone como:

```text
base + capacidades detectadas + bundles elegidos + preferencias locales
```

No hay perfiles por tipo de equipo. Un portátil puede seleccionar gaming y un
sobremesa puede omitirlo. La detección describe el hardware; no decide
preferencias físicas, dispositivos de audio, RGB ni qué aplicaciones instalar.

## Stack

| Componente | Configuración |
|---|---|
| Compositor | Hyprland Lua + UWSM |
| Shell de escritorio | Noctalia v5 |
| Terminal y shell | Ghostty, Fish, Starship, Yazi, Television y Zellij |
| Editor | Neovim/LazyVim |
| Navegación | qutebrowser, con Brave como respaldo |
| Archivos y multimedia | Dolphin, Spotify, LocalSend, Stremio, VLC y MPV |
| Teclado | Kanata, layouts configurables y bindings keyboard-first |
| Desarrollo | mise, pnpm, uv, Ruff, Difftastic, watchexec e hyperfine |
| Credenciales | 1Password CLI y agente SSH |
| Opcionales | Gaming, backup Restic, RGB OpenRGB, IA local y productividad |

La composición declara mínimos, no versiones fijas: Noctalia acepta builds
beta `>= 5.0.0_beta.9` y releases estables `>= 5.0.0`; Hyprland `>= 0.56.2`,
Kanata `>= 1.12.0` y el paquete CachyOS `cachyos-hypr-noctalia >= 1.2.5`.
Versiones posteriores se aceptan solo después de validar la configuración con
sus binarios reales. El instalador no congela paquetes, no hace downgrade y no
fuerza una actualización parcial. Si debe añadir un paquete nativo o AUR,
Shelly actualiza primero todo el sistema; si ya está todo instalado, un `apply`
no actualiza CachyOS.

## Composición y estado local

La fuente declarativa es [dotfiles.toml](dotfiles.toml). La base contiene los
módulos de shell, Hyprland, Noctalia, Kanata, terminal, navegador, editor y
aplicaciones comunes. Los manifests [packages.csv](packages.csv),
[flatpaks.csv](flatpaks.csv) y [flatpak-remotes.csv](flatpak-remotes.csv)
describen paquetes y procedencia.

Las preferencias de una máquina nunca se versionan:

| Ubicación | Contenido |
|---|---|
| `$XDG_CONFIG_HOME/dotfiles/host.toml` | bundles y preferencias confirmadas |
| `$XDG_CONFIG_HOME/dotfiles/repo` | checkout canónico registrado localmente |
| `$XDG_STATE_HOME/dotfiles/hardware/capabilities.json` | detección reemplazable |
| `$XDG_STATE_HOME/dotfiles/generated/` | fragmentos Hypr y audio generados |
| `$XDG_STATE_HOME/dotfiles/migrations/` | snapshots y rollback de despliegues |

No se guardan en Git el usuario, hostname, seriales, destino privado de backup
ni una topología de pantalla. Consulta [COMPOSITION.md](COMPOSITION.md) para el
contrato, las garantías y el rollback.

La ruta de `HOME` puede ser cualquiera. Como los módulos Stow contienen
`.config`, el instalador exige el layout XDG habitual (`$HOME/.config`) y
rechaza otro `XDG_CONFIG_HOME` antes de modificar el equipo.

### Bundles

| Bundle | Función |
|---|---|
| `gaming-core` | Steam, runtime CachyOS, Gamescope, MangoHud y wrappers |
| `gaming-launchers` | Heroic, Lutris, Faugus y ProtonPlus |
| `gaming-tools` | Ludusavi, benchmarker e informes |
| `backup` | Restic, rclone y unidades de usuario sin activar timers |
| `rgb-openrgb` | OpenRGB/liquidctl con targets exactos confirmados |
| `local-ai` | Whisper, backends locales y pegado del dictado con wtype |
| `productivity-extra` | QMD, CodexBar, ttyper y utilidades extra |

Los bundles son independientes. Si no se seleccionan, el doctor los informa sin
fallar. Si se seleccionan y faltan paquetes, configuración o un target exigido,
el doctor falla para que no haya una instalación parcialmente funcional.

La detección conserva todos los fabricantes gráficos presentes mediante sus
identificadores PCI, también en equipos híbridos Intel+NVIDIA, AMD+NVIDIA o
Intel+AMD. La capacidad `gpu-nvidia` se resuelve cuando NVIDIA forma parte del
conjunto; CHWD conserva siempre la propiedad de drivers y esta configuración no
modifica CHWD, initramfs, arranque, Btrfs, ZRAM, firmware, PWM ni `/etc`.

## Apariencias y Project Atlas

Project Atlas es la escena base. `Hyper + T` abre `/appearance`; Atlas,
Obsidian Amber, Vice Afterglow, Catppuccin Mocha, Rosé Pine Moon, Nord Night,
Dracula Violet y Tokyo Night City coordinan paleta y fondo.

Noctalia genera temas para Hyprland, GTK, Qt/KDE, Ghostty, Starship, btop,
Zellij, Micro, bat/delta, Codex y VS Code/VSCodium sin ensuciar Git. Neovim,
qutebrowser y Orca leen la paleta al iniciar. `Hyper + [` y `Hyper + ]`
cambian solo el fondo de la colección activa.

Las colecciones viven bajo
`noctalia/.local/share/wallpapers/noctalia-themes/<tema>/` y aceptan PNG,
JPEG y WebP. Cada tema recuerda el último fondo. SDDM mantiene una apariencia
Project Atlas estática porque se ejecuta fuera de la sesión del usuario.

`start-orca-background` actualiza con backup el tema de terminal de Orca y
mantiene su runtime listo. `Hyper + O` muestra u oculta su workspace especial.
1Password arranca silenciosamente tras la bandeja de Noctalia.

## Instalación nueva

Ejecuta todo como usuario normal, nunca como `root`. En CachyOS prepara las
herramientas con Polkit:

```bash
pkexec /usr/bin/shelly install standard --no-confirm git base-devel stow just
```

Si la imagen aún no incluye Shelly:

```bash
pkexec /usr/bin/pacman -S --needed shelly git base-devel stow just
```

Clona una copia canónica de `main` mediante SSH o HTTPS:

```bash
git clone --branch main git@github.com:jesus-molano/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
git status --short --branch
```

No borres una copia existente para forzar una actualización. Conserva cambios
locales y actualiza solo una rama `main` limpia con `git pull --ff-only`.

Antes de modificar nada:

```bash
./scripts/dotfiles_host.py detect
./scripts/dotfiles_host.py configure
./scripts/dotfiles_host.py show
just packages
./install.sh --check
just check
```

`dotf host configure` pregunta únicamente por decisiones que no se pueden
deducir: disposición/escala de pantallas, layouts, touchpad y bundles. Conserva
las decisiones existentes de audio, RGB, workspaces y dispositivos; confírmalas
o edítalas directamente en `host.toml`. Si eliges `backup`, exige el repositorio
Restic local. Escribe `base` o `none` para dejar solo la base común. Si Hyprland
no expone las pantallas, el asistente lo avisa y conserva el fallback automático.
En una ejecución no interactiva proporciona un `host.toml`
existente o usa `--safe-defaults`; el instalador no adivina preferencias.

Después de una simulación limpia:

```bash
just apply
# equivalente: ./install.sh
```

El instalador usa Shelly para paquetes, añade Flatpaks de usuario y despliega
Stow. Antes de sustituir conflictos crea backups recuperables. Si falla Stow,
la generación de configuración, Hyprland o un servicio gestionado, restaura
enlaces, archivos generados y el estado previo del servicio. Los paquetes,
Flatpaks, juegos y bibliotecas no se desinstalan durante el rollback.
Reactive RGB es accesorio: si su hardware, helper o activación no coinciden con
el host, muestra un aviso y la instalación principal continúa sin configurarlo.

Cierra sesión y vuelve a entrar si se añadieron variables de entorno o servicios
de usuario. Después valida:

```bash
hyprctl configerrors
noctalia config validate noctalia/.config/noctalia/config.toml
kanata --check -c kanata/.config/kanata/config.kbd
just doctor
git diff --check
```

## Migración desde los módulos legacy: dos commits obligatorios

La eliminación de módulos legacy se hace en dos fases para no romper un checkout
canónico que siga desplegado.

1. **Commit A: compatibilidad y migración.** Añade el resolvedor
   base+capacidades+bundles, los módulos portables, renderizado local, migración
   transaccional y tests. Aplica y verifica este commit en el checkout canónico
   que está desplegado: `just check`, `just apply`, `just doctor`, apariencia,
   teclado, audio, Noctalia, gaming, backup y RGB si están seleccionados.
2. **Commit B: retirada.** Solo tras esa verificación en vivo, elimina los
   módulos, aliases y documentación legacy. El snapshot de la transacción de A
   debe seguir pudiendo restaurar enlaces incluso cuando B ya no contenga los
   ficheros antiguos.

No combines ambas fases. Si A no tiene paridad demostrada, no borres módulos
legacy. `dotf host rollback` previsualiza la última transacción;
`dotf host rollback --apply` restaura solo después de verificar que no
sobrescribe cambios posteriores.

## Adaptación segura de hardware

En hardware nuevo el fallback usa `preferred`, posición automática, escala
`1`, VRR desactivado, teclado US, workspaces genéricos y no fuerza salida de
audio ni RGB. Tras confirmar preferencias, los fragmentos generados añaden
monitores, layouts, teclas de brillo, dispositivos, workspaces y audio.

Los adaptadores opcionales son no-op seguros cuando falta un periférico. RGB
nunca elige el primer controlador: requiere opt-in, coincidencia exacta de
dispositivo y zona; no controla GPU, RAM, PWM, ventiladores ni bombas. El
doctor marca cambios de hardware como aviso y deja las preferencias intactas.

Para revisar cambios sin desplegar:

```bash
dotf host refresh
dotf host show
just doctor
dotf host export nombre
```

El export es saneado: no publica identidad de máquina ni destino privado de
backup.

## Gestión diaria y validación

```bash
just list                  # plan resuelto, sin escribir
just packages              # paquetes y Flatpaks efectivos
./install.sh --list-packages
just check                 # simulación Stow hermética
just plan                  # simulación contra el HOME actual
just apply                 # instalación y despliegue
just doctor                # configuración y estado vivo, solo lectura
just lint                  # configuración reproducible
just doctor-live           # solo estado vivo
dotf host detect
dotf host configure
dotf host show
dotf host refresh
dotf host export nombre
dotf host rollback
dotf host rollback --apply
```

La configuración de `/etc` permanece separada y pide confirmación explícita:

```bash
just check-system udev
just apply-system udev
just check-system sddm
just apply-system sddm
just check-system snapper
just apply-system snapper
```

También están disponibles `just check-maintenance` y
`just apply-maintenance` para Btrfs/SMART, con confirmación antes de activar
servicios.

## Teclado, ventanas y espacios

Kanata convierte Caps Lock en Escape al pulsar y Hyper al mantener
(`Ctrl + Alt + Super + Shift`). La salida de emergencia es
`Ctrl + Space + Esc`.

Los bindings comunes no dependen de un monitor o teclado exactos:

| Atajo | Acción |
|---|---|
| `Alt + H/J/K/L` | Mover foco |
| `Alt + Shift + H/J/K/L` | Mover ventana |
| `Alt + Ctrl + H/J/K/L` | Redimensionar |
| `Alt + Q/W/E/R/U/I/O/P` | Ir a espacios 1–8 |
| `Alt + Shift + Q/W/E/R/U/I/O/P` | Enviar ventana a un espacio |
| `Alt + Tab` | Selector de ventanas |
| `Alt + X` | Cerrar ventana |
| `Alt + M` | Maximizar |
| `Alt + F` | Alternar flotante |
| `Hyper + D` | Alternar dirección de división |
| `Hyper + F` | Pantalla completa |
| `Alt + S` / `Alt + Shift + S` | Mostrar o enviar al scratchpad |
| `Alt + A` / `Alt + Shift + A` | Scratchpad de IA |
| `Alt + Z` / `Alt + Shift + Z` | Scratchpad de logs |
| `Alt + G` / `Alt + N` | Grupo de ventanas |

Los fragmentos de host pueden activar layouts extra, el cambio con
`Super + Space`, distribución de workspaces, brillo, dictado o ciclo de audio
solo si fueron confirmados. Si desaparece una pantalla, los workspaces continúan
en una salida disponible.

La primera instalación de Kanata requiere aplicar la regla udev y volver a
entrar para heredar el grupo:

```bash
pkexec /usr/bin/modprobe uinput
pkexec /usr/bin/usermod -aG input "$USER"
just apply-system udev
systemctl --user daemon-reload
systemctl --user enable kanata.service
```

## Escritorio, captura y multimedia

| Atajo | Acción |
|---|---|
| `Hyper + Enter` | Ghostty |
| `Hyper + B` | qutebrowser |
| `Hyper + E` | Dolphin |
| `Hyper + Y` | Yazi en Ghostty |
| `Hyper + O` | Orca |
| `Hyper + M` | Spotify |
| `Hyper + S` | Stremio |
| `Hyper + 1` | 1Password |
| `Alt + Space` | Launcher Noctalia |
| `Hyper + Space` | `/cmd` |
| `Hyper + J` | `/proj` |
| `Hyper + V` | `/media` |
| `Hyper + T` | Apariencias |
| `Hyper + N` | Notificaciones |
| `Hyper + P` | Captura y contexto para Orca |
| `Hyper + K` | Selector de color |
| `Hyper + C` | Cafeína |
| `Hyper + I` | Modo foco |
| `Hyper + U` | Modo demo/grabación |
| `Hyper + L` | Bloquear sesión |
| `Hyper + Q` | Menú de sesión |
| `Hyper + 7` | Panel buscable de atajos |

Stremio es Flatpak de usuario. `Hyper + V` abre el hub multimedia con Stremio,
Spotify, YouTube y suscripciones. El hub no cambia DND, audio, potencia ni
fullscreen. Usa `Hyper + C` si un reproductor no inhibe el bloqueo.

Noctalia ofrece grabación mediante `gpu-screen-recorder`, replay en RAM,
captura OCR/QR y temporizador con alarma. Las métricas de recursos se adaptan a
los dispositivos presentes. La guía completa está en
[docs/DESKTOP-WORKFLOW.md](docs/DESKTOP-WORKFLOW.md).

qutebrowser usa navegación Vim y el líder local `,`. `/proj`,
`/proj-actions`, `/ssh`, `/media`, `/typing`, `/appearance`, `/keys`,
`/ports`, `/crash` y `/cmd` exponen acciones keyboard-first. `/game` aparece
solo cuando está seleccionado `gaming-launchers`.
Consulta la [guía de qutebrowser](docs/DESKTOP-WORKFLOW.md#qutebrowser).

## Gaming

Gaming se selecciona por bundle, no por clase de equipo. `gaming-core` añade
Steam, Gamescope, MangoHud y `game-run`; `gaming-launchers` añade Heroic,
Lutris, Faugus y ProtonPlus; `gaming-tools` añade Ludusavi, benchmarker e
informes.

```bash
game-run -- juego argumentos
game-run --hud -- juego argumentos
game-run --gamescope --hud -- juego argumentos
game-run --dlss -- juego argumentos
game-run --bench nombre --duration 120 -- juego argumentos
game-run -- %command%              # opciones de lanzamiento de Steam
game-bench-report nombre
```

`game-run` usa `game-performance`, activa No molestar durante todas las
sesiones simultáneas y restaura el estado original al terminar la última. No
combines `gamemoderun` con este flujo. Mantén bibliotecas Steam en un
filesystem Linux; el doctor avisa de NTFS. DualSense y anti-cheat son
compatibilidades opcionales y dependen del juego/editor.

MangoHud y Gamescope son herramientas de medición o aislamiento por juego, no
valores globales. No se fuerzan HDR, tearing, Wine Wayland, DXVK ni límites de
FPS. Para detalles, almacenamiento, benchmarks, limitaciones y rollback, consulta
[GAMING.md](GAMING.md).

## Secretos, backup y toolchain

`with-secrets` ejecuta un comando con referencias locales de 1Password sin
exportarlas a la sesión padre. `.env.op` contiene solo referencias `op://` y
nunca se versiona.

```bash
with-secrets pnpm run deploy
```

El bundle `backup` instala Restic y rclone, pero no inventa un repositorio ni
activa timers. Configura las referencias locales, inicializa el repositorio y
activa timers solo cuando el backup se haya probado:

```bash
install -m 600 .env.op.example "$HOME/.env.op"
micro "$HOME/.env.op"
dotfiles-backup-init
dotfiles-backup
dotfiles-backup-credential-init
just apply-user-timers
```

Los wrappers `desktop-backup*` se conservan por compatibilidad, pero los
comandos nuevos son `dotfiles-backup*`. El backup incluye el checkout
registrado, documentos/proyectos, canario y staging Ludusavi cuando existe;
omite cachés, dependencias y objetos Git. La retención es 7 diarios, 5
semanales y 12 mensuales. Los timers siguen desactivados después de Stow.

```bash
just check-user-timers
systemctl --user status restic-backup.service restic-maintenance.service
```

`mise`, `uv`, Ruff y Atuin cubren el toolchain local. Android usa
`$HOME/.local/share/android-sdk` y publica `ANDROID_HOME`,
`ANDROID_SDK_ROOT` y `ANDROID_AVD_HOME` sin fijar un usuario.

```bash
just toolchain-check
just toolchain-migrate
just atlas-check
```

Yazi se integra como `y`: al salir, Fish cambia al directorio seleccionado.
Television ofrece `tv`, `tvg` y `tvt`. Delta conserva el diff lineal;
Difftastic queda disponible bajo demanda con `git dft`, `git dshow`,
`git dlog` o `git difftool`.

## Codex, Orca y Atlas

Orca y Codex CLI forman el flujo diario: Project Cockpit abre Orca y un terminal
reutilizable por repositorio; Codex se ejecuta desde ese terminal. Nvim sirve
para edición, tareas, diagnósticos y preparación de contexto.

```bash
just codex-skills-check
just codex-tests
just codex-check
just codex-config-sync
just codex-clean-rules
```

Las skills y agentes versionados se validan sin escribir. La sincronización de
Codex conserva trusts, hooks de Orca y MCP existentes. Linear es opcional:
su servidor de escritura permanece deshabilitado hasta una petición explícita y
una confirmación nueva. No se versiona OAuth ni se publica automáticamente.

El repositorio mantiene flujos para aclaración, modelado, tickets, diseño, TDD,
diagnóstico, implementación, revisión, verificación y handoff. Consulta la
[guía diaria de Codex](docs/codex/guia-diaria.md) y el
[modelo operativo](docs/codex/operating-model.md).

## Rutas principales

```text
dotfiles.toml                    base, bundles y capacidades declarativas
scripts/dotfiles_host.py         detección, configuración, generación y rollback
hypr-common/.config/hypr/        base común de Hyprland
hypr-host/.config/hypr/          fallback portable de Hyprland
audio/                           acciones y helpers PipeWire configurables
gpu-nvidia/                      caché y helper PRIME, solo con NVIDIA
gaming-core/                     runtime y wrappers gaming
gaming-launchers/                launcher Noctalia y launchers de juegos
gaming-tools/                    benchmark e informes
backup/                          Restic, rclone y unidades de usuario
rgb-openrgb/                     servicio RGB sin targets versionados
android/                         variables Android portables
templates/qmd/                   plantilla QMD renderizada localmente
noctalia/.config/noctalia/       Noctalia, paleta y colecciones
kanata/.config/kanata/           teclado
system-etc/                      archivos separados destinados a /etc
```

Orca se instala fuera de Pacman y debe proporcionar `orca-ide` en `PATH`.
