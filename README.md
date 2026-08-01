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
| Archivos | Dolphin |
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
| `Alt + S / Shift+S` | Mostrar scratchpad / enviar ventana |
| `Alt + G / N / Shift+N` | Crear grupo / pestaña siguiente / anterior |

## Capa Hyper

| Atajo | Acción |
|---|---|
| `Hyper + Enter` | Ghostty |
| `Hyper + B` | Brave |
| `Hyper + E` | Dolphin |
| `Hyper + O` | Enfocar o abrir Orca |
| `Hyper + Space` | Launcher de Noctalia |
| `Hyper + 1` | 1Password |
| `Hyper + N` | Notificaciones |
| `Hyper + P` | Captura de región |
| `Hyper + Q` | Menú de sesión |
| `Hyper + L` | Bloquear |
| `Hyper + K` | Seleccionar y copiar un color |
| `Hyper + C` | Alternar cafeína |
| `Hyper + 7` (`/` en español) | Ayuda rápida de atajos |

El historial del portapapeles se mantiene en `Super + V`.

## Noctalia

La configuración declarativa está en `noctalia/.config/noctalia/config.toml`.
La barra compacta para portátil abre con ocho escritorios semánticos sin
números ni cápsulas: navegador, terminal, código, música, archivos,
comunicación, documentación y sistema. Sus IDs siguen siendo `1`-`8`, por lo
que los atajos continúan funcionando igual. La barra conserva reloj,
multimedia, privacidad, bandeja, avisos, red, Bluetooth, volumen, brillo,
perfil energético y batería; búsqueda y sesión permanecen disponibles mediante
`Hyper + Space` y `Hyper + Q`, sin ocupar espacio permanente. No sondea la GPU
dedicada. Noctalia recarga TOML automáticamente.

La paleta `ProjectAtlas` reproduce los tokens *Waypoint Signal* de
[`project-atlas` en el commit auditado](https://github.com/jesus-molano/project-atlas/blob/2cfc15d4c7508f1f3244cba5f12e3b1682d86529/apps/viewer/app/assets/css/tokens.css):
grafito `#090a0d`–`#222731`, texto `#f1f3f5`, coral de acción `#ff5b4d` y
acentos azul, oro, verde y malva. También alimenta la plantilla de Ghostty para
mantener una sola identidad visual.

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

El instalador solo acepta el perfil allowlist `workstation`, usa Shelly para AUR,
simula Stow de forma verbosa antes de escribir y crea una copia reversible bajo
`~/.local/state/dotfiles`. No usa Paru ni aplica ajustes delicados del sistema.
Una llamada sin perfil muestra ayuda y no despliega nada.

```bash
git clone git@github.com:jesus-molano/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh workstation --check
./install.sh workstation
```

Los módulos principales de este portátil son:

```text
hypr-laptop noctalia kanata ghostty fish starship zellij nvim
git codex mimeapps fonts kvantum shell
```

El módulo histórico `gtk` queda fuera del perfil: contiene enlaces absolutos a
un tema del sistema que Stow rechaza. La configuración GTK activa se conserva
sin tocar hasta migrarla de forma independiente.

Gestión manual:

```bash
just check workstation
just apply workstation
just check hypr-laptop
just status
```

Stow se ejecuta siempre con `--no-folding` para no convertir directorios
dinámicos como `~/.codex` o `~/.config/hypr` en un único enlace.
`system-etc` nunca se trata como paquete de HOME. El único módulo habilitado
inicialmente es la regla de Kanata, que siempre se inspecciona y confirma:

```bash
just check-system udev
just apply-system udev
```

Los archivos `.env*` no se despliegan. Para limitar credenciales de 1Password a
un proceso, se usa un archivo local de referencias y el wrapper:

```bash
with-secrets pnpm run deploy
```

El wrapper ejecuta `op run`; no inyecta ni conserva secretos en el shell padre.
El helper histórico `btrfs-snapshots` tampoco forma parte del perfil: fue creado
para systemd-boot y una configuración Snapper distinta de la instalación real.

Para una tarea gráfica o de cómputo concreta en la NVIDIA híbrida, sin hacerla
GPU global del escritorio, usa `dgpu comando [argumentos...]`. El wrapper llama
a `prime-run` y limita las variables de offload al proceso hijo.

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

## Orca y Codex

`Hyper + O` enfoca la ventana existente o abre Orca mediante UWSM. Antes de un
arranque nuevo, `orca-safe-settings` conserva una copia local del JSON,
desactiva telemetría y ajusta el terminal a interlineado 1.15 y 20.000 líneas.
No edita el archivo mientras Orca está abierto, porque la aplicación es quien
lo posee en memoria.

Por preferencia expresa, los agentes iniciados por Orca conservan su modo YOLO
sin sandbox ni confirmaciones. Codex iniciado directamente mantiene el perfil
más conservador `workspace-write` + `on-request`; así cada contexto tiene una
intención clara.

Los perfiles `codex --profile fast` y `codex --profile deep`, el agente de
revisión web y las skills personales viven en el módulo `codex`. Orca gestiona
worktrees y terminales; Zellij se reserva para sesiones independientes y SSH.
`config.template.toml` es una referencia deliberada: no se carga por sí sola ni
debe sustituir el `config.toml` real, porque ese archivo contiene hooks y datos
locales de Orca. Sus claves seguras se fusionan manualmente y se comprueban con
`codex --strict-config doctor --json`.

El modo YOLO de un Codex padre iniciado por Orca también prevalece sobre el
`sandbox_mode = "read-only"` de sus subagentes. El agente `reviewer-web` mantiene
la instrucción de no escribir, pero el aislamiento técnico solo existe al
iniciarlo desde Codex directo sin `--yolo`. Usa ese contexto cuando una revisión
deba estar forzada por sandbox.

### Project Atlas

Las skills explícitas `$frontend-task`, `$reuse-first` y `$visual-direction`
están vendorizadas desde `project-atlas` en el commit
[`2cfc15d`](https://github.com/jesus-molano/project-atlas/tree/2cfc15d4c7508f1f3244cba5f12e3b1682d86529/skills).
Stow no las enlaza directamente: Atlas exige que sean copias completas o
enlaces al clon original. La sincronización instala copias reales, respalda los
tres destinos y conserva el resto de `config.toml`; el helper oficial solo
registra `[mcp_servers.component-atlas]` con el perfil `core` de seis
herramientas. Como `dist/` no está controlado por Git en Atlas, antes de ejecutar
el doctor se verifica también la huella fijada de sus 107 artefactos JavaScript
first-party.

La huella no sustituye la integridad de dependencias de `node_modules`: ese
árbol debe proceder de `pnpm install --frozen-lockfile` sobre el commit fijado.
El sincronizador no lo repara ni lo actualiza automáticamente, para evitar una
mutación amplia del clon durante el despliegue de dotfiles.

```bash
just atlas-check             # doctor oficial, solo lectura
just atlas-sync              # copia + MCP + backup + doctor
```

Se espera el clon estable en `~/dev/project-atlas`; puede cambiarse con
`PROJECT_ATLAS_CHECKOUT=/ruta/al/clon`. `PROJECT_ATLAS_HOME` queda reservado
para el almacén de datos runtime de Atlas. El script no hace `git pull`, no
compila y rechaza un clon sucio o distinto del commit vendorizado. Tras cambiar
skills o MCP, reinicia Codex y abre una tarea nueva para que descubra las
herramientas.
El `AGENTS.md` global corrige la ruta operativa para CachyOS (`doctor.sh`) y
obliga a resolver los scripts desde la propia skill cuando una referencia
upstream muestre sintaxis PowerShell.
