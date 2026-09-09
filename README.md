# Dotfiles de CachyOS + Hyprland

Configuración personal y portable de CachyOS, Hyprland y Noctalia. GNU Stow
despliega una composición por equipo:

~~~text
base + capacidades detectadas + bundles elegidos + preferencias locales
~~~

No hay perfiles rígidos de portátil o sobremesa. El hardware describe
posibilidades; las preferencias son locales.

## Guías

| Necesidad | Documento |
|---|---|
| Instalar o reinstalar | este README, en orden |
| Composición, capacidades y bundles | [COMPOSITION.md](COMPOSITION.md) |
| Rollback y migraciones | [docs/RECOVERY.md](docs/RECOVERY.md) |
| Secretos y Restic | [docs/BACKUP-AND-SECRETS.md](docs/BACKUP-AND-SECRETS.md) |
| Archivos en `/etc` | [docs/SYSTEM-ETC.md](docs/SYSTEM-ETC.md) |
| Node, Python, Android, ChatGPT y Codex | [docs/TOOLCHAIN.md](docs/TOOLCHAIN.md) |
| Atajos y uso del escritorio | [docs/DESKTOP-WORKFLOW.md](docs/DESKTOP-WORKFLOW.md) |
| Gaming | [GAMING.md](GAMING.md) |

[dotfiles.toml](dotfiles.toml) es la fuente declarativa. `just list` muestra la
composición y `just packages` muestra los paquetes efectivos.

## Límites

La base cubre Hyprland, Noctalia, Kanata, terminal, navegador, editor y
toolchain. Los bundles opcionales cubren gaming, backup, IA local y
productividad.

La instalación normal no cambia CHWD, drivers NVIDIA, kernel, initramfs,
arranque, Btrfs, ZRAM, firmware, PWM ni `/etc`. Tampoco instala el SDK de
Android ni las apps ChatGPT Community/Orca. Los ajustes de host y los temas generados permanecen fuera de
Git.

## Antes de empezar

- Usa CachyOS o Arch con Pacman y Shelly.
- Ejecuta todo como usuario normal, nunca como `root`.
- Conserva cualquier checkout y cambio local existente.
- Usa `XDG_CONFIG_HOME=$HOME/.config` o deja la variable sin definir.
- Ten red para paquetes y para el primer arranque de plugins de Noctalia.
- No mezcles esta guía con `apply-system`, timers o mantenimiento.

El instalador exige `git`, `stow`, Python 3.11 o posterior, `vercmp`, `pacman`
y `shelly`. `just` es la interfaz recomendada.

## Instalación nueva

### 1. Instala los prerrequisitos

~~~bash
pkexec /usr/bin/shelly install standard --no-confirm git base-devel python stow just
~~~

Si Shelly todavía no existe:

~~~bash
pkexec /usr/bin/pacman -S --needed shelly git base-devel python stow just
~~~

No continúes si Pacman o Shelly informan de un error.

### 2. Clona el checkout canónico

~~~bash
git clone --branch main git@github.com:jesus-molano/dotfiles.git "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
git status --short --branch
~~~

Para HTTPS, usa `https://github.com/jesus-molano/dotfiles.git`. El checkout
`$HOME/.dotfiles` debe ser `main`. No apliques Stow desde otra worktree.

### 3. Detecta y configura el host

`dotf` aún puede no estar desplegado. Usa el script directo:

~~~bash
./scripts/dotfiles_host.py detect
./scripts/dotfiles_host.py configure
./scripts/dotfiles_host.py show
~~~

`configure` pregunta por pantallas, teclado, touchpad, bundles, ubicación de
Noctalia y grabación. Conserva las decisiones locales existentes de audio,
workspaces y dispositivos.

`host.toml` vive en `$XDG_CONFIG_HOME/dotfiles/`. El hardware y los generados
viven bajo `$XDG_STATE_HOME/dotfiles/`. En una ejecución no interactiva,
proporciona un `host.toml` o usa `--safe-defaults`.

### 4. Simula todo

~~~bash
just packages
just check
just plan
~~~

`just check` valida la composición en un HOME temporal. `just plan` revisa el
preflight exacto del HOME actual, incluidos paquetes, Flatpaks, módulos y
retiradas. No sigas si algo es inesperado.

Si falta un paquete, el apply actualiza CachyOS por completo con Shelly antes de
instalarlo. Nunca hace una actualización parcial de Arch.

### 5. Aplica

~~~bash
just apply
~~~

Instala solo lo que falta y despliega los módulos resueltos. Antes de sustituir
conflictos crea copias y un journal. Un fallo posterior revierte Stow, generados
y servicios de usuario gestionados.

El rollback no desinstala paquetes Pacman/AUR, Flatpaks, juegos ni bibliotecas.
`system-etc/`, timers de backup y mantenimiento quedan fuera de este paso.

### 6. Valida

~~~bash
hyprctl configerrors
noctalia config validate "$HOME/.config/noctalia"
kanata --check -c kanata/.config/kanata/config.kbd
just doctor
git diff --check
~~~

Cierra sesión y vuelve a entrar si cambian variables, grupos o servicios de
usuario. Si Noctalia arrancó sin red, conecta el equipo, reinícialo y repite
`just doctor` para comprobar los plugins remotos.

## Si algo falla

No repitas `just apply` a ciegas:

~~~bash
just check
just doctor
dotf host rollback
~~~

`dotf host rollback` solo previsualiza. `dotf host rollback --apply` restaura
la última transacción y protege los generados modificados después.

Antes de desplegar Fish, usa:

~~~bash
./scripts/dotfiles_host.py rollback
./scripts/dotfiles_host.py rollback --apply
~~~

Si aparece `rollback-incomplete` o `stow-ready`, resuelve esa transacción antes
de aplicar otra. Sigue [docs/RECOVERY.md](docs/RECOVERY.md).

## Reinstalación o actualización

No borres un checkout existente:

~~~bash
cd "$HOME/.dotfiles"
git status --short --branch
git fetch origin
git pull --ff-only
~~~

Usa `pull --ff-only` solo con `main` limpia. Después:

~~~bash
dotf host refresh
dotf host show
just packages
just check
just plan
just apply
just doctor
~~~

En hardware nuevo revisa pantallas, teclado, audio y bundles.

## Opcionales

No los actives durante la ruta base:

~~~bash
# /etc: simular y aplicar un único módulo
just check-system MODULO
just apply-system MODULO

# Timers Restic: solo tras probar backup y restore
just check-user-timers
just apply-user-timers

# Toolchain
just toolchain-check
just android-check
just atlas-check
~~~

Para el automount usa [docs/SYSTEM-ETC.md](docs/SYSTEM-ETC.md). Para Restic usa
[docs/BACKUP-AND-SECRETS.md](docs/BACKUP-AND-SECRETS.md).

## Comandos diarios

~~~bash
just list
just packages
just check
just plan
just apply
just doctor
just lint
just ci
just doctor-live

dotf host detect
dotf host configure
dotf host show
dotf host refresh
dotf host export nombre
dotf host rollback
~~~

`just check` simula en un HOME temporal. `just plan` compara contra el HOME
actual sin escribir. `just doctor-live` audita solo el despliegue vivo.

## CI y licencia

`just ci` valida Shell, Python, Fish, Zellij y contratos críticos sin sesión
gráfica, secretos ni permisos administrativos. GitHub Actions repite la suite en
Arch. CI no demuestra compatibilidad con hardware físico.

Este repositorio personal no declara una licencia de software.
