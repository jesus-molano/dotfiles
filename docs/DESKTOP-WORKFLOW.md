# Flujo desktop keyboard-first

Esta guía describe el uso diario del perfil `desktop`. No sustituye la
instalación del [README](../README.md). El perfil trata desarrollo, gaming y
multimedia como flujos principales. En desarrollo usa Orca y Codex CLI como
núcleo. Usa Neovim para editar, ejecutar tareas, diagnosticar y preparar
contexto.

`Hyper` es la tecla modificadora que Kanata expone al mantener Caps Lock.

## Orca y Codex CLI

1. Pulsa `Hyper + J` para abrir `/proj`.
2. Selecciona `Sesión Orca + terminal` para el repositorio.
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

## Project Cockpit

`/proj` descubre repositorios dentro de `~/projects`, `~/work`, `~/.dotfiles` y
`~/orca/workspaces`. Sus opciones son:

| Opción | Uso |
|---|---|
| `Sesión Orca + terminal` | Acción diaria. Registra el repositorio en Orca y abre Ghostty/Zellij. |
| `Orca` | Enfoca o abre Orca después de registrar el repositorio. |
| `Ghostty` | Abre o recupera el terminal Zellij del repositorio. |
| `Nvim` | Abre Nvim de forma explícita. Úsalo para código, contexto o diagnóstico. |
| `Tareas` | Muestra tareas de `justfile`, `mise.toml` y `package.json`. |
| `Preview` | Inicia `scripts.preview` o `scripts.dev` del proyecto. |

Las tareas se eligen con `fzf` dentro de un terminal. Task Hub de Nvim detecta
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
| `Hyper + O` | Enfoca o abre Orca. |
| `Hyper + S` | Enfoca o abre Stremio. |
| `Hyper + P` | Captura una región y prepara contexto para Orca. |
| `Hyper + T` | Inicia o termina dictado local y pega el resultado. |
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
| `dictation_toggle` | Graba o transcribe y pega el texto. |
| `focus_toggle` | Activa o restaura el modo foco. |
| `demo_mode` | Activa el modo demo con grabación. |
| `direct_scanout_toggle` | Prueba direct scanout auto para juegos. Es experimental y no cambia la configuración persistente. |
| `doctor_host` | Abre la auditoría del host en Ghostty. |
| `system_monitor` | Abre btop. |

## Gaming y multimedia

Estos flujos son independientes del cockpit de desarrollo:

| Entrada | Uso |
|---|---|
| `Hyper + G` | Enfocar o abrir Steam. |
| `/game` | Abrir Steam, Heroic, Lutris, Faugus o SCX Manager. |
| `Hyper + S` | Enfocar Stremio si ya existe; abrirlo si no existe. |
| `Hyper + V` o `/media` | Elegir Stremio, Spotify, YouTube o suscripciones. |
| `Hyper + M` | Enfocar o abrir Spotify. |
| Teclas multimedia | Reproducir, pausar y cambiar pista en reproductores compatibles. |

`/media` no cambia el perfil energético, No Molestar, el audio ni el modo de
ventana. No usa `game-run`. Stremio se abre desde la instalación Flatpak de
usuario declarada por el perfil común.

Para YouTube, qutebrowser es la ruta predeterminada. `,v` abre la página actual
en mpv y `;v` permite elegir un enlace. El perfil instala `yt-dlp` para este
flujo. mpv es opcional: úsalo cuando prefieras su control de teclado; no se
fuerza para todos los vídeos.

`game-run` sí pertenece al flujo gaming. Activa rendimiento y protege No
Molestar solo durante el juego. Si hay dos juegos simultáneos, el último en
cerrarse restaura el estado original. Usa las opciones de lanzamiento descritas
en [GAMING.md](../GAMING.md).

Los reproductores compatibles pueden inhibir el estado inactivo. Si una web o
una aplicación no lo hace, activa cafeína con `Hyper + C` y desactívala al
terminar. No uses modo foco para ver contenido: también cambia la potencia y
oculta la barra.

## Task Hub de Neovim

El líder de Neovim es Espacio. Abre Nvim con la acción `Nvim` de `/proj` o desde
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

### Dictado

El dictado es local y bajo demanda. Antes del primer uso descarga un modelo:

```bash
just dictation-setup base
```

`Hyper + T` empieza a grabar. Pulsa de nuevo para detener, transcribir, copiar y
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

`Hyper + U` activa modo demo. Añade la grabación de pantalla al modo foco. Al
desactivarlo, detiene solo la grabación iniciada por el modo y restaura barra,
No Molestar, cafeína y perfil energético anteriores.

No uses modo foco para juegos. `game-run` mantiene su propio comportamiento de
pantalla completa y notificaciones. Si estaba activo, `game-run` lo restaura
antes de iniciar; mientras haya una sesión gaming, el modo foco no se activa.

## Noctalia: estado y presentación

La barra incluye tres herramientas de trabajo:

- **Dev Pulse** muestra el proyecto de la ventana activa, rama Git, número de
  cambios y procesos Codex locales. Se actualiza cada treinta segundos. Es de
  solo lectura: no abre repositorios, no ejecuta prompts y no modifica Git.
- **Special Workspaces** muestra los scratchpads poblados. Usa `Alt + A` para
  IA y `Alt + Z` para logs sin abandonar el workspace principal.
- **Screen Mirror** permite preparar un espejo de pantalla desde el widget de
  la barra. Úsalo para demos o para comprobar una salida; no sustituye la
  configuración permanente de monitores.

La base revisada fija Dev Pulse `1.0.0`, Special Workspaces `1.4.0` y Screen
Mirror `1.0.0`. `just doctor-live desktop` detecta un cambio de versión antes
de aceptarlo como parte del perfil.

El grabador de Noctalia sigue disponible en el centro de control. El modo demo
lo controla solo durante su propia sesión.

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
| `,v` / `;v` | Abrir la página o un enlace elegido en mpv. |
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

1. `Hyper + U` para activar demo y grabación.
2. Abre Screen Mirror desde Noctalia si necesitas duplicar una salida.
3. Pulsa `Hyper + U` al terminar para restaurar el estado anterior.

### Ver una serie o película

1. Pulsa `Hyper + S` para abrir o recuperar Stremio.
2. Si el monitor intenta apagarse, activa cafeína con `Hyper + C`.
3. Desactiva cafeína al terminar.

### Ver YouTube con teclado

1. Pulsa `Hyper + V` y elige YouTube o suscripciones.
2. Navega con los hints de qutebrowser.
3. Usa `,v` para enviar la página a mpv o `;v` para elegir un enlace.

### Jugar

1. Pulsa `Hyper + G` para Steam o abre `/game` para otro launcher.
2. Usa `game-run -- %command%` como opción de lanzamiento cuando corresponda.
3. Deja que `game-run` gestione potencia y No Molestar; no actives modo foco.

### Investigar desde el navegador

1. Abre qutebrowser con `Hyper + B`.
2. Busca, por ejemplo, `O ghc nombre_de_la_API`.
3. Usa `;m` para copiar un enlace concreto como Markdown.
4. Usa `Hyper + P` si necesitas capturar una salida visual antes de abrir Orca.
