# Mapa de trabajo de dotfiles

- La fuente canónica es `main`; `~/.dotfiles` debe apuntar a esa rama después de fusionar y validar un cambio.
- `hypr-laptop/` y `noctalia/` son el escritorio activo. `hypr/`, `waybar/`, `rofi/`, `swaync/` y `gaming/` son heredados y no pertenecen al perfil workstation.
- Usa `just check workstation` antes de desplegar y `just apply workstation` solo después de revisar la simulación. Nunca ejecutes Stow sobre todos los directorios.
- Trata `system-etc/` por separado, con destino `/etc`, copia previa y confirmación explícita.
- No leas ni muestres `.env`; ejecuta secretos solo para el proceso que los necesita mediante `with-secrets`.
- En CachyOS usa Pacman o Shelly. CHWD es dueño del driver NVIDIA; no instales ramas genéricas ni cambies ZRAM, arranque, Btrfs, entrada o servicios sin inspección real.
- Conserva cambios ajenos y realiza cambios pequeños y reversibles.
- Termina con las validaciones de sintaxis del módulo, simulación Stow, `git diff --check` y un resumen de pruebas y riesgos no verificables.
