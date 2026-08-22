# Backup y secretos

Esta guía cubre el bundle `backup`, Restic y los secretos locales. La instalación
normal no inventa un destino, no inicializa un repositorio y no activa timers.

## Límites de seguridad

- `.env.op` contiene referencias `op://`, no secretos en claro, y no se versiona.
- `with-secrets` inyecta secretos solo en el proceso hijo.
- El repositorio Restic es una preferencia privada de cada host.
- Stow despliega unidades de usuario, pero las deja desactivadas.
- Un rollback de dotfiles no elimina snapshots ni desinstala Restic.

## Preparación

Selecciona `backup` al configurar el host. El asistente exige un
`backup.repository` local.

Después del primer despliegue, crea el archivo privado a partir del ejemplo y
edítalo sin mostrarlo en terminales compartidos:

~~~bash
install -m 600 .env.op.example "$HOME/.env.op"
micro "$HOME/.env.op"
~~~

No añadas `.env.op` a Git. Comprueba que 1Password CLI puede resolver las
referencias antes de continuar.

Inicializa solo el destino exacto configurado:

~~~bash
dotfiles-backup-init
~~~

El comando muestra el destino de forma oculta y exige escribir `INICIALIZAR`.
Si el repositorio ya existe y las credenciales funcionan, no lo recrea.

## Primera copia y validación

Ejecuta una copia manual:

~~~bash
dotfiles-backup
~~~

Cada ejecución crea un canario privado nuevo con permisos `0600`. El token no
se imprime. El snapshot recibe la etiqueta `desktop` y el host efectivo de
Restic.

Prueba después el mantenimiento completo:

~~~bash
dotfiles-backup-maintenance
~~~

La comprobación:

1. Selecciona por `RESTIC_HOST` y etiqueta `desktop`.
2. Rechaza un snapshot de más de 72 horas.
3. Ejecuta `restic check`.
4. Restaura con `--verify` el ID exacto seleccionado.
5. Compara el canario restaurado.
6. Ejecuta `restic prune` solo si todo lo anterior termina bien.

Esto evita que un snapshot de otro equipo o un backup antiguo dé una señal falsa
de recuperación.

## Timers de usuario

Los servicios usan una credencial cifrada de systemd. Créala solo después de
validar la copia manual:

~~~bash
dotfiles-backup-credential-init
just check-user-timers
just apply-user-timers
~~~

`dotfiles-backup-credential-init` cifra `RESTIC_PASSWORD` para el usuario con
`systemd-creds` y la vincula al host y TPM2. Si falla, deja los timers
desactivados y conserva el flujo manual hasta resolver el soporte local.

`just apply-user-timers` exige `ACTIVAR` y habilita únicamente:

- `restic-backup.timer`
- `restic-maintenance.timer`

Comprueba el resultado:

~~~bash
systemctl --user status restic-backup.service restic-maintenance.service
systemctl --user list-timers restic-backup.timer restic-maintenance.timer
journalctl --user -u restic-backup.service -u restic-maintenance.service
~~~

## Contenido y retención

La copia incluye las rutas existentes declaradas en
`backup/.config/restic/dotfiles.paths`, el checkout canónico registrado,
`$XDG_CONFIG_HOME/dotfiles`, el staging de Ludusavi y el canario. Incluye los
objetos Git del checkout para poder recuperar una rama completa. Omite cachés,
dependencias y artefactos regenerables según `dotfiles.excludes`.

La política conserva 7 snapshots diarios, 5 semanales y 12 mensuales.

Los nombres `desktop-backup*` son wrappers de compatibilidad. Usa
`dotfiles-backup*` en documentación y automatizaciones nuevas.

## Recuperación

Lista primero los snapshots del host correcto:

~~~bash
restic_host=${RESTIC_HOST:-$(hostname)}
with-secrets restic snapshots --host "$restic_host" --tag desktop
~~~

Restaura a un directorio vacío, nunca directamente sobre `HOME`:

~~~bash
restore_dir="$(mktemp -d)"
with-secrets restic restore ID_EXACTO --verify --target "$restore_dir"
~~~

Inspecciona la copia, selecciona los archivos necesarios y restaura de forma
manual. La recuperación completa de dotfiles se explica en
[RECOVERY.md](RECOVERY.md).
