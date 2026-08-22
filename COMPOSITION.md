# Composición de hosts

Cada instalación se resuelve como:

```text
base + capacidades detectadas + bundles elegidos + preferencias locales
```

No existen perfiles ni aliases por clase de equipo. Un portátil puede usar
gaming y un equipo de sobremesa puede omitirlo.

## Fuentes de verdad

- `dotfiles.toml` declara base, bundles y condiciones por capacidad.
- `dotfiles.toml` declara también versiones mínimas compatibles, nunca pins.
- `scripts/dotfiles_host.py` detecta hechos de hardware y resuelve el plan.
- `$XDG_CONFIG_HOME/dotfiles/host.toml` guarda elecciones locales con permisos
  privados.
- `$XDG_STATE_HOME/dotfiles/hardware/capabilities.json` y
  `$XDG_STATE_HOME/dotfiles/generated/` contienen estado derivado y
  reemplazable.
- `packages.csv`, `flatpaks.csv` y `flatpak-remotes.csv` declaran paquetes y
  procedencia.

La detección no almacena ni exporta identidad sensible. Se ejecuta con HOME y
directorios XDG temporales para que una consulta de hardware no genere cachés o
estado en la sesión real. Un export de host se sanea antes de convertirse en
candidato de configuración compartida.

El usuario y la ruta de `HOME` son dinámicos. Los módulos GNU Stow modelan
`.config` dentro de ese HOME, por lo que el instalador exige
`XDG_CONFIG_HOME=$HOME/.config` (o la variable sin definir). Un XDG de
configuración distinto se rechaza antes de detectar, instalar o desplegar para
no dividir la configuración entre dos raíces. `XDG_STATE_HOME` sí puede cambiar.

Las versiones posteriores al mínimo permanecen admitidas. Antes de desplegar,
Noctalia, Hyprland y Kanata validan la configuración real. Una versión inferior
detiene el proceso antes de tocar HOME; la corrección es actualizar CachyOS de
forma completa, no congelar, degradar ni actualizar paquetes aislados.

Noctalia declara una transición explícita: `minimum = "5.0.0_beta.9"` aplica
a builds beta y `stable_minimum = "5.0.0"` a releases estables. Es necesario
porque `vercmp` ordena `5.0.0` por debajo de `5.0.0_beta.9`, aunque la release
estable sea compatible. Un consumidor del plan debe leer ambos campos: si la
versión contiene `_beta.`, compara contra `minimum`; en otro caso, contra
`stable_minimum` cuando exista. `stable_minimum` es opcional, debe ser una
versión Pacman válida y no se permiten campos desconocidos.

Si falta cualquier paquete seleccionado, también uno de AUR, Shelly sincroniza
y actualiza primero todo CachyOS. Así sus dependencias se instalan en una
transacción coherente con Arch. Si no falta ningún paquete, aplicar dotfiles no
provoca una actualización del sistema.

## Resolución segura

`dotf host detect` no modifica el sistema. `dotf host configure` confirma solo
preferencias no deducibles: disposición física de pantallas, teclado, touchpad,
bundles, ubicación/horario de Noctalia y formato del grabador. Conserva las
secciones locales de audio, RGB, workspaces y dispositivos para que se confirmen
por separado. La ubicación se guarda con permisos privados en `host.toml` y se
renderiza en `$XDG_CONFIG_HOME/noctalia/zz-host-overrides.toml`; nunca forma
parte de la configuración base ni de un export. El bundle `backup` exige un
`backup.repository` local y tampoco lo incluye en exports. `dotf host refresh`
compara un nuevo informe con las decisiones guardadas y no sobrescribe nada sin
confirmación. `base` o `none` vacían los bundles de forma explícita. Si el
asistente se ejecuta sin acceso a las pantallas de Hyprland, lo avisa y conserva
el fallback automático.

Al resolver módulos, Hyprland da prioridad a los fragmentos generados, después
al directorio desplegado, al fallback de `hypr-host` y finalmente a la base
común. Sin configuración específica usa `preferred`, posición automática,
escala `1`, VRR desactivado, teclado US y workspaces genéricos.

El mapa de teclado común no depende del hardware detectado. Kanata conserva
Caps como Escape al pulsar y Hyper al mantener. La composición conserva también
Alt+H/J/K/L, Alt+Q/W/E/R/U/I/O/P y todos los bindings Hyper. Zellij permanece
transparente hasta `Ctrl+G`, que evita capturar `Alt+Z` y `Alt+X` de Hyprland.
Los fragmentos de host solo añaden adaptadores confirmados, como brillo, audio
o dictado.

## Bundles

| Bundle | Propósito |
|---|---|
| `gaming-core` | Steam, runtime de CachyOS, Proton, Gamescope y MangoHud |
| `gaming-launchers` | Heroic, Lutris, Faugus y ProtonPlus |
| `gaming-tools` | Ludusavi, benchmark y wrappers |
| `backup` | Restic, rclone y operaciones de copia voluntarias |
| `rgb-openrgb` | OpenRGB/liquidctl; control solo con destino exacto confirmado |
| `local-ai` | Herramientas locales opcionales |
| `productivity-extra` | Utilidades de productividad opcionales |

La ausencia de un bundle es informativa. Si se selecciona y no funciona, el
doctor lo trata como fallo. No se habilita un servicio de RGB si su dispositivo
o zona no se resuelve de forma única.

## Rollback

Antes de reemplazar enlaces, el instalador registra el plan, los módulos legacy,
los archivos generados de Hyprland, audio y Noctalia, y el estado de servicios bajo
`$XDG_STATE_HOME/dotfiles/migrations/`. Los conflictos ajenos se mueven a
`$XDG_STATE_HOME/dotfiles/backups/`. Si falla Stow o una validación posterior,
restaura todo desde el snapshot, incluso aunque el checkout ya no contenga los
módulos legacy. No desinstala paquetes, Flatpaks, juegos, bibliotecas ni datos.

`dotf host rollback` previsualiza la última transacción. Solo
`dotf host rollback --apply` modifica el sistema y se niega a sobrescribir un
archivo generado que haya cambiado después del despliegue.

La retirada de los módulos legacy requiere dos fases. El commit A conserva sus
fuentes, se aplica desde el checkout canónico y se valida en vivo. El commit B
puede borrarlas únicamente después de demostrar esa paridad; un host que no haya
aplicado A no debe saltar directamente a B. La secuencia exacta está en el
[README](README.md#migración-desde-los-módulos-legacy-dos-commits-obligatorios).

CHWD sigue siendo responsable de los controladores. La composición no toca
arranque, initramfs, Btrfs, ZRAM, firmware, PWM ni `/etc`.

Los módulos de `system-etc` usan otra transacción: primero simulan el destino,
después crean un journal con preimágenes y revierten las copias parciales en
orden inverso. No participan en `just apply` y siempre requieren confirmación
separada.
