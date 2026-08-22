# Mapa de trabajo de dotfiles

- La fuente canónica es `main`; `~/.dotfiles` debe apuntar a esa rama después de fusionar y validar un cambio.
- La composición no usa perfiles: combina base, capacidades, bundles y preferencias locales. El estado de host vive bajo XDG y no se versiona.
- Los bundles gaming son portables y pueden seleccionarse en cualquier host. Mantén los adapters de hardware específicos detrás de capacidades y confirmación explícita.
- Usa `just check` para la simulación hermética y `just plan` para el preflight exacto del HOME antes de desplegar. Ejecuta `just apply` solo después de revisar ambos resultados. Nunca ejecutes Stow sobre todos los directorios.
- Trata `system-etc/` por separado, con destino `/etc`, copia previa y confirmación explícita.
- No leas ni muestres `.env`; ejecuta secretos solo para el proceso que los necesita mediante `with-secrets`.
- En CachyOS usa Pacman o Shelly. CHWD es dueño del driver NVIDIA; no instales ramas genéricas ni cambies ZRAM, arranque, Btrfs, entrada o servicios sin inspección real.
- Conserva cambios ajenos y realiza cambios pequeños y reversibles.
- Termina con las validaciones de sintaxis del módulo, simulación Stow, `git diff --check` y un resumen de pruebas y riesgos no verificables.
