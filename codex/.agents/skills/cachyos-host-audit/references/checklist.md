# Checklist de cierre

- Kernel y distribución identificados.
- Perfil CHWD y `nvidia-smi` coherentes, sin proponer otro driver.
- Unidades fallidas y timers relevantes inspeccionados.
- Subvolumen/sistema de archivos y política Snapper identificados antes de tocar Btrfs.
- Hyprland y Noctalia validados por sus herramientas, si están disponibles.
- Composición resuelta y cambios de capacidades comprobados antes del estado vivo.
- Paquetes gaming y coexistencia Ananicy/GameMode comprobados solo si hay un bundle gaming seleccionado.
- Estado de backup separado de la presencia de credenciales; nunca mostrar valores.
- Cambios de `/etc` o servicios quedan como propuesta con destino y rollback.
- Diferencias entre rama de trabajo, dotfiles desplegados y host vivo explicadas.
