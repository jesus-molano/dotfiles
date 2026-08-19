# Flujo desktop keyboard-first

Esta guía describe el uso diario del perfil `desktop`. No sustituye la
instalación del [README](../README.md). El perfil trata desarrollo, gaming y
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

Codex CLI no se inicia automáticamente. Ejecútalo en ese terminal cuando una
tarea requiera un agente. Orca conserva el trabajo visual, los worktrees y sus
terminales. Este reparto evita abrir Nvim, un agente y varios terminales para
cada proyecto aunque solo quieras hablar con Codex.

## Proyectos y acciones avanzadas

`/proj` descubre repositorios dentro de `~/projects`, `~/work`, `~/.dotfiles` y
`~/orca/workspaces`. Muestra exactamente una fila por repositorio, con su nombre
y ruta. Al elegir una fila, registra el repositorio en Orca, enfoca o abre Orca
y abre Ghostty/Zellij en el directorio del proyecto.

`/proj-actions` muestra acciones específicas para un repositorio:

| Opción | Uso |
|---|---|
| `Sesión Orca + terminal` | Repite la sesión normal de `/proj`. |
| `Orca` | Enfoca o abre Orca después de registrar el repositorio. |
| `Ghostty` | Abre o recupera el terminal Zellij del repositorio. |
| `Nvim` | Abre Nvim de forma explícita. Úsalo para código, contexto o diagnóstico. |
| `Tareas` | Muestra tareas de `justfile`, `mise.toml` y `package.json`. |
| `Preview` | Inicia `scripts.preview` o `scripts.dev` del proyecto. |

Usa `/proj-actions` solo cuando necesites una acción distinta de la sesión
normal. Las tareas se eligen con `fzf` dentro de un terminal. Task Hub de Nvim detecta
las mismas fuentes más `.vscode/tasks.json`.

Para que `Preview` abra también qutebrowser, añade una URL local explícita al
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

## Launcher y atajos del desktop

| Atajo | Acción |
|---|---|
| `Alt + Space` | Abre el launcher general de Noctalia. |
| `Hyper + J` | Abre `/proj`. |
| `Hyper + Space` | Abre `/cmd`. |
| `Hyper + V` | Abre `/media`. |
| `Hyper + W` | Usa el siguiente fondo del tema activo. |
| `Hyper + [` / `Hyper + ]` | Usa el fondo anterior/siguiente del tema activo. |
| `Hyper + T` | Rota a la siguiente apariencia completa. |
| `Hyper + R` | Inicia o detiene el dictado local y pega el texto. |
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
| `capture_context` | Ejecuta la captura OCR y enfoca Orca. |
| `capture_qr` | Selecciona un QR y copia su valor como dato sensible de un solo pegado. |
| `bug_capsule` | Agrupa captura, OCR, metadatos limitados y el replay reciente. |
| `media_convert` | Convierte imágenes o vídeos mediante una interfaz breve. |
| `demo_studio` | Elige audio, webcam y fuente; la misma acción detiene su grabación. |
| `window_width_save` / `window_width_restore` | Conserva un ancho útil por clase y workspace. |
| `dictation_toggle` | Graba o transcribe y pega el texto. |
| `focus_toggle` | Activa o restaura el modo foco. |
| `demo_mode` | Activa el modo demo con grabación. |
| `direct_scanout_toggle` | Prueba direct scanout auto para juegos. Es experimental y no cambia la configuración persistente. |
| `doctor_host` | Abre la auditoría del host en Ghostty. |
| `system_monitor` | Abre btop. |

El launcher también ofrece cuatro proveedores de trabajo:

| Prefijo | Resultado |
|---|---|
| `/appearance` | Aplica una escena de color y fondo coordinados. |
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

`/media` no cambia el perfil energético, No Molestar, el audio ni el modo de
ventana. No usa `game-run`. Stremio se abre desde la instalación Flatpak de
usuario declarada por el perfil común.

Para YouTube, qutebrowser es la ruta única del perfil. `/media` abre la portada
o las suscripciones y el vídeo se reproduce en la propia página.

`game-run` sí pertenece al flujo gaming. Activa rendimiento y protege No
Molestar solo durante el juego. Si hay dos juegos simultáneos, el último en
cerrarse restaura el estado original. Usa las opciones de lanzamiento descritas
en [GAMING.md](../GAMING.md).

Tras tres ejecuciones con `game-run --bench NOMBRE -- COMANDO [ARGUMENTOS...]`, `/game` muestra un
informe. Calcula mediana FPS, 1% low, dispersión de frametimes y registra kernel,
driver y perfil. También está disponible como `game-bench-report NOMBRE` o con
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
grabación. `Hyper + U` también restaura No Molestar, cafeína, barra y perfil
energético al estado anterior. Un clic en la cámara detiene solo el vídeo; pulsa
después `Hyper + U` para salir del modo demo. La cámara desaparece cuando no hay
una grabación activa.

La acción `demo_studio` de `/cmd` es el modo avanzado. Permite elegir audio del
escritorio, micrófono, ambos o ninguno; webcam flotante; y monitor enfocado o
portal. El modo predeterminado usa el monitor enfocado. Demo Studio solo detiene
el proceso que inició y no interfiere con el replay de Noctalia.

No uses modo foco para juegos. `game-run` mantiene su propio comportamiento de
pantalla completa y notificaciones. Si estaba activo, `game-run` lo restaura
antes de iniciar; mientras haya una sesión gaming, el modo foco no se activa.

## Noctalia: estado y presentación

La barra incluye estas herramientas de trabajo:

- **Special Workspaces** muestra los scratchpads poblados. Usa `Alt + A` para
  IA y `Alt + Z` para logs sin abandonar el workspace principal.

La base revisada fija Special Workspaces `1.4.0`. `just doctor-live desktop`
detecta un cambio de versión antes de aceptarlo como parte del perfil.

El grabador de Noctalia también está disponible en el centro de control. El
modo demo detiene solo la grabación que inició él mismo.

La cápsula de recursos muestra CPU, temperatura de CPU, uso y temperatura de GPU
y porcentaje de RAM. Ya no muestra VRAM. La barra tampoco incluye espejo de
pantalla ni estado periódico del repositorio.

## Apariencias y RGB

`/appearance` ofrece seis escenas: Atlas, Catppuccin Mocha, Rosé Pine Moon,
Nord Night, Dracula Violet y Tokyo Night City. Cada escena cambia la paleta de
Noctalia y el fondo como una sola acción. `Hyper + T` rota estas escenas sin
abrir el menú.
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
demás plantillas activas. Starship se genera fuera del checkout. Neovim y
qutebrowser leen la paleta al abrir una instancia nueva. Orca la aplica antes
de abrir su ventana y no reescribe sus ajustes mientras la interfaz está
abierta.
SDDM mantiene Project Atlas: se ejecuta antes de la sesión y no participa en
este cambio de apariencia.

En el desktop, `reactive-rgb.service` usa dos indicadores independientes dentro
de `Aura Addressable 1`. Los LED 1–12 de la CPU siguen exclusivamente la
temperatura de CPU. Los LED 13–60 de los ventiladores internos siguen
exclusivamente la temperatura de la GPU. La CPU usa azul por debajo de 50 °C,
verde entre 50 y 69 °C, naranja entre 70 y 84 °C y rojo desde 85 °C. La GPU
usa azul por debajo de 50 °C, verde entre 50 y 69 °C, naranja entre 70 y 82 °C
y rojo desde 83 °C. Las líneas frontal y superior permanecen blancas mediante
la zona fija de la placa y los
dos canales NZXT. OpenRGB nunca selecciona la iluminación de la GPU o la RAM y
no modifica PWM. El estado vivo se guarda en `XDG_RUNTIME_DIR`, no en el NVMe,
y los destinos se reaplican cada cinco minutos aunque la banda térmica no
cambie. Comandos útiles:

```bash
reactive-rgb status
reactive-rgb dry-run --mode thermal
systemctl --user enable --now reactive-rgb.service
systemctl --user status reactive-rgb.service
```

## qutebrowser

qutebrowser conserva sus defaults Vim. Usa `,` como líder local. Los atajos
nativos siguen siendo preferibles cuando ya existen: `f` y `F` para hints, `J`
y `K` para pestañas, `gC` para clonar, `ym` para copiar la página actual como
Markdown y `Ctrl + E` dentro de un campo para editarlo con Neovim.

### Líder coma

| Atajo | Acción |
|---|---|
| `,a` / `,A` | Alternar bloqueo para el dominio actual o globalmente durante la sesión. |
| `,d` | Alternar modo oscuro para el dominio actual. |
| `,u` | Actualizar listas de bloqueo. |
| `,e` / `,r` | Editar o recargar `config.py`. |
| `,p` | Abrir navegación privada. |
| `,t` / `,T` | Escribir un comando para enfocar o mover una pestaña. |
| `,c` / `,g` | Clonar la pestaña actual o volver a la última pestaña. |
| `,s` / `,S` / `,X` | Escribir un comando para guardar, cargar o borrar una sesión nombrada. |
| `,y` | Copiar la página actual como enlace Markdown. |
| `;m` | Elegir un enlace con hints y copiarlo como Markdown. |
| `,o` / `,O` / `,D` | Abrir la última descarga, abrir su directorio o limpiar descargas terminadas. |
| `,B` / `;B` | Abrir la página o un enlace elegido en Brave. |
| `,E` | Editar el campo de texto activo con Neovim. |
| `,i` / `,I` | Abrir DevTools a la derecha o mover el foco entre DevTools y la página. |

`qutebrowser` limpia parámetros de seguimiento habituales al copiar una URL.
El userscript de `;m` usa el portapapeles directamente; no transforma el texto
del sitio en un comando del navegador.

### Búsquedas técnicas

Escribe `o` u `O`, seguido del prefijo y la consulta. Ejemplo:

```text
O mdn AbortController
```

| Prefijo | Destino |
|---|---|
| `aw` | ArchWiki |
| `archpkg` | Paquetes oficiales de Arch |
| `aur` | AUR |
| `gh` / `ghc` | GitHub general o búsqueda de código |
| `mdn` | MDN Web Docs |
| `npm` / `pypi` | npm o PyPI |
| `qute` | Documentación de qutebrowser |
| `so` | Stack Overflow |
| `yt` | YouTube |
| `g` | Google |

## Flujos cortos

### Implementar una tarea

1. `Hyper + J` y selecciona `Sesión Orca + terminal`.
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
2. Navega con los hints de qutebrowser.
3. Reproduce el vídeo directamente en qutebrowser.

### Jugar

1. Pulsa `Hyper + G` para Steam o abre `/game` para otro launcher.
2. Usa `game-run -- %command%` como opción de lanzamiento cuando corresponda.
3. Deja que `game-run` gestione potencia y No Molestar; no actives modo foco.

### Investigar desde el navegador

1. Abre qutebrowser con `Hyper + B`.
2. Busca, por ejemplo, `O ghc nombre_de_la_API`.
3. Usa `;m` para copiar un enlace concreto como Markdown.
4. Usa `Hyper + P` si necesitas capturar una salida visual antes de abrir Orca.
