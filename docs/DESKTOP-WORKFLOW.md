# Flujo desktop keyboard-first

Esta guía describe el uso diario keyboard-first. No sustituye la
instalación del [README](../README.md). La composición trata desarrollo, gaming y
multimedia como flujos principales. En desarrollo usa Orca y Codex CLI como
núcleo. Usa Neovim para editar, ejecutar tareas, diagnosticar y preparar
contexto.

`Hyper` es la tecla modificadora que Kanata expone al mantener Caps Lock.

## Orca y Codex CLI

1. Pulsa `Hyper + J` para abrir `/proj`.
2. Selecciona el repositorio por nombre y ruta.
3. Trabaja con Orca y Codex CLI desde el terminal que abre la sesión.
4. Abre Nvim solo cuando necesites editar, ejecutar Task Hub, investigar un
   diagnóstico o revisar contexto.

La sesión predeterminada registra el repositorio en Orca, enfoca o abre Orca y
abre Ghostty en el directorio del proyecto. Ghostty se adjunta a una sesión de
Zellij identificada por ese repositorio. Reabrir la sesión vuelve a adjuntarse;
no crea otro proceso de Zellij ni otro servidor de preview.

Zellij permanece en modo transparente para no capturar atajos de Codex, Neovim
o Hyprland. Pulsa `Ctrl + G` para abrir su hub de comandos y `Esc` para volver al
modo transparente. `Alt + Z` continúa reservado al scratchpad de logs y
`Alt + X` al cierre de ventanas.

Codex CLI no se inicia automáticamente. Ejecútalo en ese terminal cuando una
tarea requiera un agente. Orca conserva el trabajo visual, los worktrees y sus
terminales. Este reparto evita abrir Nvim, un agente y varios terminales para
cada proyecto aunque solo quieras hablar con Codex.

## Ventanas, espacios y teclado

Kanata convierte Caps Lock en Escape al pulsar y en Hyper al mantener. La salida
de emergencia es `Ctrl + Space + Esc`.

| Atajo | Acción |
|---|---|
| `Alt + H/J/K/L` | Mover el foco. |
| `Alt + Shift + H/J/K/L` | Mover la ventana. |
| `Alt + Ctrl + H/J/K/L` | Redimensionar. |
| `Alt + Q/W/E/R/U/I/O/P` | Ir a los espacios 1–8. |
| `Alt + Shift + Q/W/E/R/U/I/O/P` | Enviar la ventana a un espacio. |
| `Alt + Tab` | Abrir el selector de ventanas. |
| `Alt + X` | Cerrar la ventana. |
| `Alt + M` | Maximizar. |
| `Alt + F` | Alternar flotante. |
| `Hyper + D` | Alternar la dirección de división. |
| `Hyper + F` | Alternar pantalla completa. |
| `Ctrl + G` en Zellij | Abrir el hub; `Esc` vuelve al modo transparente. |

## Proyectos y acciones avanzadas

`/proj` descubre repositorios dentro de `~/projects`, `~/work`, `~/.dotfiles` y
`~/orca/workspaces`. Muestra exactamente una fila por repositorio, con su nombre
y ruta. Al elegir una fila, registra el repositorio en Orca, enfoca o abre Orca
y abre Ghostty/Zellij en el directorio del proyecto.

`/proj-actions` muestra acciones específicas para un repositorio:

| Opción | Uso |
|---|---|
| `Orca session and terminal` | Repite la sesión normal de `/proj`. |
| `Open in Orca` | Enfoca o abre Orca después de registrar el repositorio. |
| `Open terminal` | Abre o recupera el terminal Zellij del repositorio. |
| `Open in Nvim` | Abre Nvim de forma explícita. Úsalo para código, contexto o diagnóstico. |
| `Open tasks` | Muestra tareas de `justfile`, `mise.toml` y `package.json`. |
| `Open preview` | Inicia `scripts.preview` o `scripts.dev` del proyecto. |

Usa `/proj-actions` solo cuando necesites una acción distinta de la sesión
normal. Las tareas se eligen con `fzf` dentro de un terminal. Task Hub de Nvim detecta
las mismas fuentes más `.vscode/tasks.json`.

Para que `Preview` abra también Brave, añade una URL local explícita al
`package.json`:

```json
{
  "projectCockpit": {
    "previewUrl": "http://localhost:5173"
  }
}
```

Solo se aceptan URLs `localhost` o `127.0.0.1`. El navegador espera hasta 30
segundos a que el servidor responda. Si no defines esa clave, la acción inicia
el servidor en su terminal y muestra su salida.

## Launcher y atajos

| Atajo | Acción |
|---|---|
| `Alt + Space` | Abre el launcher general de Noctalia. |
| `Hyper + J` | Abre `/proj`. |
| `Hyper + Space` | Abre `/cmd`. |
| `Hyper + V` | Abre `/media`. |
| `Hyper + 7` | Alterna `/keys`, el panel buscable de atajos activos. |
| `Hyper + [` / `Hyper + ]` | Usa el fondo anterior/siguiente del tema activo. |
| `Hyper + T` | Abre el selector de apariencias. |
| `Hyper + R` | Inicia o detiene el dictado local y pega el texto. |
| `Hyper + H` | Recorre las salidas configuradas; sin esa configuración, abre los controles de audio. |
| `Hyper + O` | Enfoca o abre Orca. |
| `Hyper + S` | Enfoca o abre Stremio. |
| `Hyper + P` | Captura una región y prepara contexto para Orca. |
| `Hyper + I` | Alterna modo foco. |
| `Hyper + U` | Activa modo demo y grabación. |
| `Alt + S` | Alterna el scratchpad general. |
| `Alt + A` | Alterna el scratchpad de IA. |
| `Alt + Z` | Alterna el scratchpad de logs. |
| `Alt + Shift + S/A/Z` | Envía la ventana activa al scratchpad indicado. |

`/cmd` contiene estas acciones sin tener que recordar el comando de shell:

| Acción | Resultado |
|---|---|
| `Capture context` | Ejecuta la captura OCR y enfoca Orca. |
| `Read QR code` | Selecciona un QR y copia su valor como dato sensible de un solo pegado. |
| `Create bug capsule` | Agrupa captura, OCR, metadatos limitados y el replay reciente. |
| `Convert media` | Convierte imágenes o vídeos mediante una interfaz breve. |
| `Demo Studio` | Elige audio, webcam y fuente; la misma acción detiene su grabación. |
| `Save window width` / `Restore window width` | Conserva un ancho útil por clase y workspace. |
| `Toggle local dictation` | Graba o transcribe y pega el texto. |
| `Toggle focus mode` | Activa o restaura el modo foco. |
| `Prepare demo mode` | Activa el modo demo con grabación. |
| `Toggle direct scanout` | Prueba direct scanout auto para juegos. Es experimental y no cambia la configuración persistente. |
| `Audit this computer` | Abre la auditoría del host en Ghostty. |
| `System monitor` | Abre btop. |

El launcher también ofrece estos proveedores de trabajo:

| Prefijo | Resultado |
|---|---|
| `/appearance` | Aplica una escena de color y fondo coordinados. |
| `/keys` | Separa los atajos activos por función; cada categoría abre una lista buscable. |
| `/ports` | Lista solo los servidores TCP del usuario y abre el puerto revalidado. |
| `/crash` | Prepara contexto Markdown de un coredump reciente y enfoca Orca. |
| `/typing` | Abre Ttyper en inglés, ejercicios de código o Keybr. |

`/typing` usa el teclado inglés del desktop. La práctica rápida abre 50 palabras
de `english1000`; la larga abre 100. Los modos de código ofrecen Python,
JavaScript y Rust. Keybr se abre en una ventana Brave tipo aplicación y respeta
el layout activo del sistema.

## Gaming y multimedia

Estos flujos son independientes del cockpit de desarrollo:

| Entrada | Uso |
|---|---|
| `Hyper + G` | Enfocar o abrir Steam. |
| `/game` | Abrir launchers y los informes de benchmarks MangoHud disponibles. |
| `Hyper + S` | Enfocar Stremio si ya existe; abrirlo si no existe. |
| `Hyper + V` o `/media` | Elegir Stremio, Spotify, YouTube o suscripciones. |
| `Hyper + M` | Enfocar o abrir Spotify. |
| Teclas multimedia | Reproducir, pausar y cambiar pista en reproductores compatibles. |

`/media` no cambia el modo energético, No Molestar, el audio ni el modo de
ventana. No usa `game-run`. Stremio se abre desde la instalación Flatpak de
usuario declarada por la base común.

Para YouTube, Brave es la ruta única de la base. `/media` abre la portada
o las suscripciones y el vídeo se reproduce en la propia página.

`game-run` sí pertenece al flujo gaming. Activa rendimiento y protege No
Molestar solo durante el juego. Si hay dos juegos simultáneos, el último en
cerrarse restaura el estado original. Usa las opciones de lanzamiento descritas
en [GAMING.md](../GAMING.md).

Tras tres ejecuciones con `game-run --bench NOMBRE -- COMANDO [ARGUMENTOS...]`, `/game` muestra un
informe. Calcula mediana FPS, 1% low, dispersión de frametimes y registra kernel,
driver y modo energético. También está disponible como `game-bench-report NOMBRE` o con
`--json`.

Los reproductores compatibles pueden inhibir el estado inactivo. Si una web o
una aplicación no lo hace, activa cafeína con `Hyper + C` y desactívala al
terminar. No uses modo foco para ver contenido: también cambia la potencia y
oculta la barra.

## Task Hub de Neovim

El líder de Neovim es Espacio. Abre Nvim con la acción `Nvim` de `/proj-actions` o desde
un terminal del proyecto. Task Hub usa Overseer y no sustituye el terminal de
Codex.

| Atajo | Acción |
|---|---|
| `Espacio j r` | Elegir y ejecutar una tarea detectada. |
| `Espacio j l` | Mostrar u ocultar la lista de tareas. |
| `Espacio j a` | Elegir una acción para la tarea actual. |
| `Espacio j s` | Abrir una tarea de shell. |

Los errores van a quickfix y diagnostics. Si una tarea falla, Nvim abre la lista
de resultados. Esto sirve para `just`, `mise`, scripts de paquetes, tareas VS
Code, test y depuración DAP.

## Captura OCR y dictado local

### Captura a contexto

`Hyper + P` selecciona una región, abre Satty para anotar y ejecuta OCR en
español e inglés. Guarda la imagen en `~/Pictures/Screenshots`, genera Markdown
en `~/.local/state/desktop-context/latest.md`, lo copia al portapapeles y enfoca
Orca. No envía la imagen ni el texto a ningún agente.

Para abrir el Markdown en Nvim en vez de Orca:

```bash
capture-context --focus nvim
```

`capture-qr` usa una selección independiente y acepta solo QR. No imprime su
contenido. `bug-capsule` crea una carpeta privada bajo
`~/.local/state/bug-capsules`, copia la captura, añade el OCR y pide guardar los
últimos 90 segundos del replay. El resultado es local; no crea issues ni publica.

`media-convert` sin argumentos abre un selector para imagen a JPG/PNG o vídeo a
MP4/GIF. Conserva el original, evita sobrescrituras y copia la URI del resultado.

### Dictado

El dictado es local y bajo demanda. Antes del primer uso descarga un modelo:

```bash
just dictation-setup base
```

`Hyper + R` empieza a grabar. Pulsa de nuevo para detener, transcribir, copiar y
pegar el texto en la ventana activa. Usa `local-dictation status` para comprobar
si está grabando. Los modelos permitidos son `tiny`, `base` y `small`. La
descarga usa una revisión fijada y valida tamaño y SHA-256 antes de instalar el
modelo. `setup` también activa el modelo elegido de forma persistente. Ejecuta
`local-dictation model` para mostrar la ruta activa. `base` es el valor
predeterminado.

## Modo foco y demo

`Hyper + I` activa modo foco. Activa cafeína, cambia a rendimiento, activa No
Molestar y oculta la barra. Pulsa el mismo atajo para restaurar el estado que
había antes.

`Hyper + U` alterna modo demo. La primera pulsación abre una confirmación modal.
Selecciona **Iniciar demo** para iniciar la grabación de la pantalla enfocada; usa
**Cancelar** para no cambiar el estado del equipo. La barra permanece visible y muestra una cámara roja mientras
graba. Pulsa otra vez `Hyper + U`, o haz clic en la cámara roja, para detener la
grabación. `Hyper + U` también restaura No Molestar, cafeína, barra y modo
energético al estado anterior. Un clic en la cámara detiene solo el vídeo; pulsa
después `Hyper + U` para salir del modo demo. La cámara desaparece cuando no hay
una grabación activa.

La acción `demo_studio` de `/cmd` es el modo avanzado. Permite elegir audio del
escritorio, micrófono, ambos o ninguno; webcam flotante; y monitor enfocado o
portal. El modo predeterminado usa el monitor enfocado. Demo Studio solo detiene
el proceso que inició y no interfiere con el replay de Noctalia.

La captura mantiene `1920x1080` a 60 FPS por defecto. Para una grabación
concreta, usa por ejemplo
`demo-studio start --resolution 2560x1440 --frame-rate 60`. También acepta
`DEMO_STUDIO_RESOLUTION` y `DEMO_STUDIO_FRAME_RATE`; no cambia el preset del
host ni la configuración de Noctalia.

No uses modo foco para juegos. `game-run` mantiene su propio comportamiento de
pantalla completa y notificaciones. Si estaba activo, `game-run` lo restaura
antes de iniciar; mientras haya una sesión gaming, el modo foco no se activa.

## Noctalia: estado y presentación

La barra incluye estas herramientas de trabajo:

- **Special Workspaces** muestra los scratchpads poblados. Usa `Alt + A` para
  IA y `Alt + Z` para logs sin abandonar el workspace principal.

La base revisada fija Special Workspaces `1.4.0`. `just doctor` detecta un
cambio de versión antes de aceptarlo como parte de la composición.

El grabador de Noctalia también está disponible en el centro de control. El
modo demo detiene solo la grabación que inició él mismo.

La cápsula de recursos muestra CPU, temperatura de CPU, uso y temperatura de GPU
y porcentaje de RAM. Ya no muestra VRAM. La barra tampoco incluye espejo de
pantalla ni estado periódico del repositorio.

## Apariencias

`/appearance` ofrece ocho escenas: Atlas, Obsidian Amber, Catppuccin Mocha,
Rosé Pine Moon, Nord Night, Dracula Violet, Tokyo Night City y Vice Afterglow. Cada escena
cambia la paleta de Noctalia y el fondo como una sola acción. `Hyper + T` abre
el selector sin cambiar la escena actual.
Usa `appearance-switch next` o `previous` desde terminal para recorrerlas.
El proveedor `/wall` muestra solo los fondos de la apariencia activa y cambia
la imagen sin cambiar la paleta. Cada carpeta admite una cantidad variable de
fondos. Al cambiar de apariencia, cierra y vuelve a
abrir `/wall` para consultar la nueva colección. El panel gráfico de fondos
requiere su acción `Refresh` si ya estaba abierto.
Cada apariencia recuerda su último fondo y lo restaura al volver; si ese
archivo ya no existe, usa el primer nombre de archivo disponible. Para editar las
colecciones, añade o retira PNG, JPEG o WebP en
`~/.dotfiles/noctalia/.local/share/wallpapers/noctalia-themes/<tema>/`.
Los cambios aparecen al volver a abrir `/wall`; no requieren desplegar Stow.

Noctalia regenera Hyprland, Ghostty, GTK, Qt, btop, Starship, Bat/Delta y las
demás plantillas activas. Starship se genera fuera del checkout. Neovim lee la
paleta al abrir una instancia nueva. Orca la aplica antes
de abrir su ventana y no reescribe sus ajustes mientras la interfaz está
abierta.
Thunderbird recibe los colores de la paleta activa en tiempo real mediante una
extensión local. `just apply` vuelve a generar la extensión y su manifiesto. En
una instalación nueva, aplica una vez la política que prepara el instalador:

```bash
pkexec install -D -m 644 \
  "$HOME/.local/state/dotfiles/thunderbird/policies.json" \
  /etc/thunderbird/policies/policies.json
```

Reinicia Thunderbird después de instalar esa política. Los cambios posteriores
de `/appearance` no requieren reiniciar la aplicación.
El widget de sesión y las acciones normales de `Hyper + Q` usan el color
primario de la apariencia activa. El fondo del panel usa la superficie de esa
misma paleta. Solo la acción final de apagado conserva la variante destructiva.
Los diálogos GTK, incluido el cierre de Ghostty, siguen la paleta generada; una
aplicación abierta antes del cambio puede requerir reinicio.
Los ajustes antiguos de Kitty y Kvantum que no tienen paridad se conservan
como [referencias legacy](reference/README.md); no son módulos desplegables.
El SDDM personalizado usa un tema neutral y no consume el estado de apariencia
de Noctalia. El identificador interno `project-atlas` se conserva para mantener
compatible el despliegue existente. La sincronización de Noctalia Greeter no se
aplica a este SDDM y sus ejecutables auxiliares no están instalados. Solo el
botón final de apagado usa el color de peligro.

## Brave y Vimium C

Brave es el navegador predeterminado y Vimium C aporta navegación por teclado.
Sus atajos principales son `f` para hints, `j` y `k` para desplazarse, `J` y
`K` para cambiar de pestaña, `o` para buscar, `/` para buscar texto, `x` para
cerrar y `X` para restaurar una pestaña.

Chromium impide que las extensiones actúen en `brave://`, Chrome Web Store y
otras superficies protegidas. En esas páginas usa los atajos nativos de Brave:
`Ctrl + L`, `Ctrl + Tab`, `Ctrl + W` y `Ctrl + Shift + T`.

Brave sigue automáticamente el color de superficie oscuro de `/appearance` mediante la
política dinámica `BrowserThemeColor`. La activación administrativa se realiza
una sola vez, después de `appearance-switch prepare`:

```bash
setup-brave-project-atlas-policy --check
setup-brave-project-atlas-policy --install
```

El segundo comando usa Polkit. Instala un observador `systemd` de sistema y un
helper propiedad de root. El helper acepta solo `BrowserThemeColor` y copia la
política validada a `/etc/brave/policies/managed/project-atlas-theme.json`. No
sustituye archivos ajenos. Brave muestra que está administrado y desactiva su
selector manual de tema mientras la política está instalada. Cada cambio
posterior de `/appearance` se aplica sin reiniciar el navegador. Rollback:
`setup-brave-project-atlas-policy --remove`.

No se carga un tema desempaquetado adicional. La política dinámica evita
conflictos con temas locales bloqueados o desactivados por Brave.

Vimium C conserva una interfaz oscura de alto contraste. Abre sus opciones y
copia el contenido de
`~/.local/share/brave-project-atlas-theme/vimium-c.css` en **Custom CSS for
Vimium C UI**. Esta personalización afecta a hints, HUD, Vomnibar y FindBar; no
inyecta estilos generales en las páginas web.

## Flujos cortos

### Implementar una tarea

1. `Hyper + J` y selecciona `Orca session and terminal`.
2. Ejecuta Codex CLI en Ghostty si la tarea necesita un agente.
3. Usa `Espacio j r` en Nvim solo para una tarea, test o diagnóstico.
4. Si aparece un fallo visual, usa `Hyper + P` y pega el contexto preparado en
   el flujo que estés revisando.

### Preparar una demo

1. Pulsa `Hyper + U` y selecciona **Iniciar demo** para activar demo y grabación.
2. Pulsa `Hyper + U` al terminar para restaurar el estado anterior.

### Ver una serie o película

1. Pulsa `Hyper + S` para abrir o recuperar Stremio.
2. Si el monitor intenta apagarse, activa cafeína con `Hyper + C`.
3. Desactiva cafeína al terminar.

### Ver YouTube con teclado

1. Pulsa `Hyper + V` y elige YouTube o suscripciones.
2. Navega con los hints de Vimium C.
3. Reproduce el vídeo directamente en Brave.

### Jugar

1. Pulsa `Hyper + G` para Steam o abre `/game` para otro launcher.
2. Usa `game-run -- %command%` como opción de lanzamiento cuando corresponda.
3. Deja que `game-run` gestione potencia y No Molestar; no actives modo foco.

### Investigar desde el navegador

1. Abre Brave con `Hyper + B`.
2. Pulsa `o` para buscar en historial, marcadores y pestañas mediante Vimium C.
3. Pulsa `f` para seguir un enlace sin usar el ratón.
4. Usa `Hyper + P` si necesitas capturar una salida visual antes de abrir Orca.
