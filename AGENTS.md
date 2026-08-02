# Mapa de trabajo de dotfiles

- La fuente canónica es `main`; `~/.dotfiles` debe apuntar a esa rama después de fusionar y validar un cambio.
- El host activo inspeccionado es `desktop`: usa `hypr-desktop/`, `noctalia/` y `gaming/`. `workstation` se conserva para el portátil, pero no es el host activo.
- `gaming/` pertenece exclusivamente a `desktop`; no lo añadas a `workstation` ni a configuraciones compartidas con el portátil.
- Usa `just check desktop` antes de desplegar este host y `just apply desktop` solo después de revisar la simulación. Nunca ejecutes Stow sobre todos los directorios.
- Trata `system-etc/` por separado, con destino `/etc`, copia previa y confirmación explícita.
- No leas ni muestres `.env`; ejecuta secretos solo para el proceso que los necesita mediante `with-secrets`.
- En CachyOS usa Pacman o Shelly. CHWD es dueño del driver NVIDIA; no instales ramas genéricas ni cambies ZRAM, arranque, Btrfs, entrada o servicios sin inspección real.
- Conserva cambios ajenos y realiza cambios pequeños y reversibles.
- Termina con las validaciones de sintaxis del módulo, simulación Stow, `git diff --check` y un resumen de pruebas y riesgos no verificables.
