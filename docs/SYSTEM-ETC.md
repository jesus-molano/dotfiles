# Configuración separada de /etc

`just apply` nunca despliega `system-etc/`. Los cambios administrativos se
simulan y aplican por módulo, con Polkit, confirmación y copia previa.

## Módulos permitidos

| Módulo | Destino |
|---|---|
| `udev` | `/etc/udev/` |
| `sddm` | `/etc/sddm.conf.d/` y `/etc/sddm/themes/` |
| `snapper` | `/etc/snapper/` |
| `systemd` | `/etc/systemd/system/` |

No uses Stow contra `/etc`.

## Política dinámica de Brave

La integración de Brave no copia una política mutable dentro del repositorio.
`appearance-switch` genera un objeto que contiene solo `BrowserThemeColor`
bajo `$XDG_STATE_HOME/dotfiles/appearance-switch/brave-policies/managed/`.
La instalación crea un helper y dos unidades root. El `.path` observa ese
archivo. El servicio valida la clave y copia el resultado a
`/etc/brave/policies/managed/project-atlas-theme.json`:

~~~bash
appearance-switch prepare
setup-brave-project-atlas-policy --check
setup-brave-project-atlas-policy --install
~~~

El navegador mostrará el estado administrado mientras la política exista. El
helper instalado es propiedad de root y no ejecuta código desde HOME. El
marcador root `/var/lib/project-atlas-brave-policy/installation` distingue los
archivos propios de políticas ajenas. El instalador puede actualizar o retirar
una instalación propia incompleta aunque el archivo de usuario ya no exista.
Rollback:

~~~bash
setup-brave-project-atlas-policy --remove
~~~

## Flujo por módulo

Simula primero:

~~~bash
just check-system udev
just check-system sddm
just check-system snapper
just check-system systemd
~~~

Lee cada diff. Aplica solo el módulo revisado:

~~~bash
just apply-system MODULO
~~~

La receta exige escribir `APLICAR`. Cada ejecución crea:

- un journal bajo `$XDG_STATE_HOME/dotfiles/system-backups/`;
- preimágenes de destinos existentes;
- marcas para retirar los destinos que antes no existían.

Si una copia falla o el proceso recibe `INT` o `TERM`, revierte una sola vez en
orden inverso. Si el rollback parcial falla, conserva
`rollback-incomplete.tsv` con los destinos pendientes.

La ruta de la última copia correcta queda en
`$XDG_STATE_HOME/dotfiles/last-system-backup`. No hay una orden genérica que
restaure el snapshot completo: revisa su `journal.tsv` y sus preimágenes antes
de cualquier restauración manual.

## Automount de backups

El módulo `systemd` necesita el archivo privado
`$XDG_CONFIG_HOME/dotfiles/systemd-mnt-backups.conf`:

~~~ini
MNT_BACKUPS_UUID=UUID_DEL_FILESYSTEM
MNT_BACKUPS_UID=1000
MNT_BACKUPS_GID=1000
~~~

Los tres valores se validan y se renderizan sin versionar la identidad del
disco. Aplica y activa en dos pasos distintos:

~~~bash
just check-system systemd
just apply-system systemd
just apply-backup-automount
~~~

La última receta verifica que las dos unidades sean archivos regulares ya
copiados, exige `ACTIVAR`, ejecuta `daemon-reload` y habilita únicamente
`mnt-backups.automount`.

Rollback de la activación:

~~~bash
pkexec /usr/bin/systemctl disable --now mnt-backups.automount
pkexec /usr/bin/systemctl daemon-reload
~~~

La restauración de los archivos de unidad sigue siendo una operación separada
basada en la preimagen del snapshot.

## Activación posterior

`apply-system` copia archivos. No recarga ni habilita servicios de forma
genérica. Después de aplicar, ejecuta solo la acción específica documentada para
ese módulo y equipo.

Para Kanata, tras revisar `udev`:

~~~bash
pkexec /usr/bin/modprobe uinput
pkexec /usr/bin/usermod -aG input "$USER"
just apply-system udev
systemctl --user daemon-reload
systemctl --user enable kanata.service
~~~

Vuelve a entrar en la sesión para heredar el grupo `input`.

El mantenimiento físico se mantiene aparte:

~~~bash
just check-maintenance
just apply-maintenance
~~~

`apply-maintenance` exige `ACTIVAR` y afecta solo a
`btrfs-scrub@-.timer` y `smartd.service`. Aplica la configuración de Snapper por
separado y solo después de inspeccionar Btrfs en el host real.
