# Recuperación y rollback

Hay tres ámbitos distintos. No mezcles sus mecanismos:

| Ámbito | Mecanismo |
|---|---|
| HOME, enlaces Stow, generados y servicios de usuario gestionados | transacción de `install.sh` |
| Paquetes Pacman/AUR y Flatpaks | estado del gestor de paquetes; no se revierte automáticamente |
| `/etc` | journal y preimágenes de `system-etc-transaction.sh` |

## Rollback de un despliegue HOME

Cada aplicación crea un snapshot bajo
`$XDG_STATE_HOME/dotfiles/migrations/`. Antes de aplicar:

~~~bash
dotf host rollback
~~~

Este comando solo previsualiza la última transacción. Para restaurarla:

~~~bash
dotf host rollback --apply
~~~

El rollback se niega a sobrescribir un generado modificado después del
despliegue. Si no puede completar una restauración, conserva el snapshot y marca
`rollback-incomplete`. Corrige primero esa condición antes de volver a aplicar.

Si Fish todavía no está desplegado, usa el CLI directo desde el checkout:

~~~bash
./scripts/dotfiles_host.py rollback
./scripts/dotfiles_host.py rollback --apply
~~~

Los paquetes, Flatpaks, juegos, librerías y backups permanecen instalados. Esta
decisión evita desinstalar dependencias que ya usaba el equipo antes del apply.

## Retirar la composición aplicada

~~~bash
just remove
~~~

La receta simula, exige `RETIRAR` y retira exactamente los enlaces y generados
del último plan aplicado. No vuelve a resolver el hardware actual para adivinar
qué retirar.

## Recuperación de /etc

Cada `just apply-system MODULO` guarda `journal.tsv` y `preimages/` bajo
`$XDG_STATE_HOME/dotfiles/system-backups/`. Un fallo, `INT` o `TERM` durante la
copia activa el rollback automático.

Una aplicación correcta no tiene todavía una orden `rollback-system`. Para una
restauración posterior:

1. Lee `$XDG_STATE_HOME/dotfiles/last-system-backup`.
2. Abre el `journal.tsv` de ese snapshot.
3. Verifica cada destino y su preimagen.
4. Restaura solo los destinos confirmados con Polkit.
5. Ejecuta la recarga específica del subsistema afectado.

No copies a ciegas todo `preimages/` sobre `/etc`. Consulta
[SYSTEM-ETC.md](SYSTEM-ETC.md).

## Migración desde módulos legacy

La retirada de módulos legacy requiere dos commits:

1. El commit A añade la composición nueva y conserva las fuentes antiguas.
2. Aplica A desde el checkout canónico y valida configuración, teclado, audio,
   Noctalia y los bundles seleccionados.
3. El commit B retira módulos, aliases y documentación antiguos.
4. Conserva el snapshot de A hasta demostrar que B funciona en vivo.

No combines ambas fases. Un host que no haya aplicado A no debe saltar a B.

## Recuperación desde Restic

Restaura primero en un directorio vacío y verifica el contenido. El backup
incluye el checkout canónico con objetos Git y la configuración privada del
host. Sigue [BACKUP-AND-SECRETS.md](BACKUP-AND-SECRETS.md) para seleccionar el
host y el snapshot exactos.
