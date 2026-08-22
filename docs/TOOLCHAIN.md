# Toolchain de desarrollo

La composición base despliega configuración portable para Node, Python,
Android y herramientas de terminal. No descarga el SDK de Android, no acepta
licencias y no instala Orca.

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

## Codex, Orca y Project Atlas

Orca debe instalarse fuera de Pacman y proporcionar `orca-ide` en `PATH`.
Si no existe, `start-orca-background` avisa y deja operativo el resto del
escritorio.

Comprobaciones disponibles:

~~~bash
just atlas-check
just codex-skills-check
just codex-tests
just codex-check
~~~

Las operaciones que escriben son explícitas:

~~~bash
just atlas-sync
just codex-config-sync
just codex-clean-rules
~~~

La sincronización conserva trusts, hooks de Orca y MCP no gestionados. Linear
permanece opcional y su escritura necesita autorización humana nueva.

Consulta la [guía diaria de Codex](codex/guia-diaria.md) y el
[modelo operativo](codex/operating-model.md).
