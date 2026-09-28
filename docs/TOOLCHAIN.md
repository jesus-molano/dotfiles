# Toolchain de desarrollo

La composición base despliega configuración portable para Node, Python,
Android y herramientas de terminal. No descarga el SDK de Android, no acepta
licencias y no instala automáticamente ChatGPT Community.

## Node y JavaScript

`npm`, `pnpm` y `mise` son dependencias directas. El módulo `npm` despliega
`$HOME/.npmrc` y dirige instalaciones globales a `$HOME/.npm-global`.

Comprueba una migración anterior de fnm sin cambiarla:

~~~bash
just toolchain-check
~~~

Aplica la migración solo después de leer el plan:

~~~bash
just toolchain-migrate
~~~

La receta valida mise, reconfigura Atlas y revierte si la transición falla.

## Python

`uv` gestiona entornos y herramientas Python. Ruff cubre formato y lint. Evita
instalar herramientas globales con `pip` cuando exista un paquete Pacman o un
entorno de proyecto.

## Android

El SDK local esperado vive en:

~~~text
$HOME/.local/share/android-sdk
~~~

La configuración publica `ANDROID_HOME`, `ANDROID_SDK_ROOT`,
`ANDROID_AVD_HOME` y las rutas de herramientas sin fijar un nombre de usuario.

Descarga manualmente las Command-line Tools oficiales de Android. Después
acepta las licencias de Google de forma explícita. Estos dotfiles nunca lo hacen
por ti.

Comprueba el resultado:

~~~bash
just android-check
~~~

## Terminal y navegación

- Yazi se abre con `y`; Fish cambia al directorio elegido al salir.
- Television ofrece `tv`, `tvg` y `tvt`.
- Delta conserva el diff lineal.
- Difftastic queda disponible con `git dft`, `git dshow`, `git dlog` y
  `git difftool`.
- Zellij deja pasar los atajos de Hyprland hasta abrir su modo con `Ctrl+G`.
- Bat usa el tema generado por Noctalia y es una dependencia directa.

## ChatGPT Community, Codex y Project Atlas

ChatGPT Community es la app principal. El paquete externo `codex-desktop`
se instala con Pacman; los dotfiles no descargan ni construyen su contenido.
El wrapper `codex-desktop`, su entrada de menú y los flags Electron se versionan
en `hypr-common`. Ambos lanzamientos desactivan el contador comunitario.
Se usa Wayland nativo; `--lang=es` no garantiza que toda la interfaz esté traducida.

`start-chatgpt-background` inicia la app al entrar en Hyprland, sin duplicar un
proceso existente. La regla coloca sus ventanas en `special:chatgpt silent`.
`Hyper + W` alterna ese escritorio; las capturas y proyectos usan `--focus` para
revelarlo sin ocultarlo cuando ya está visible. `Hyper + O` queda libre y
`Hyper + C` conserva el modo cafeína.

La instalación inicial de ChatGPT Community usa la base oficial Linux, sin
features comunitarias ni actualizador automático. Las actualizaciones de la
app son manuales. El navegador integrado está disponible; el control nativo
Linux requiere construir y validar por separado `computer-use-linux`.

CodexBar CLI mantiene una receta local revisada en
`packages/codexbar-cli/PKGBUILD`. `just codexbar-check` compara la instalación,
la receta fijada y la última release oficial. `just codexbar-test` descarga el
archivo oficial, verifica el checksum publicado y prueba el proveedor Codex sin
instalar. `just codexbar-build` repite esa prueba, construye el paquete con
Shelly y lo copia a `~/.cache/dotfiles/packages/codexbar-cli`.

Shelly construye la receta, pero no descubre releases de GitHub. Cuando
`codexbar-check` indique una versión nueva, hay que revisar sus notas y actualizar
la versión y los checksums del `PKGBUILD`. La instalación permanece bajo Pacman
y se hace de forma explícita con `pkexec pacman -U <paquete>`.

Antes de sustituir una versión, conserva el paquete anterior en el mismo
directorio de caché. El rollback usa esa ruta exacta con
`pkexec pacman -U <paquete-anterior>` y vuelve a ejecutar
`just codexbar-test` después de la transacción.

AI configuration (rules, skills, roles, hooks and MCP for Claude Code and
Codex) is deployed and checked with `just ai-plan`, `just ai-sync` and
`just ai-check`. See the [AI guide](ai.md).
