---
name: cachyos-host-audit
description: Audita de forma no destructiva un host CachyOS con Hyprland, Noctalia, NVIDIA, gaming, Btrfs y systemd. Úsala al diagnosticar el estado del equipo, revisar cambios de dotfiles, evaluar mantenimiento o preparar una mejora que dependa del hardware y los servicios reales.
---

# Auditoría de host CachyOS

## Objetivo

Recopila evidencia separando la validez reproducible de los dotfiles del estado
vivo. Produce hallazgos priorizados y no cambia paquetes, servicios, `/etc`,
GPU, arranque, Btrfs ni dispositivos.

## Flujo

1. Lee el `AGENTS.md` aplicable y detecta el repositorio de dotfiles.
2. Ejecuta primero comprobaciones reproducibles. Si existe, usa:

   ```bash
   just lint desktop
   ```

3. Ejecuta después el wrapper de solo lectura desde el directorio de la skill:

   ```bash
   bash scripts/host-audit.sh desktop
   ```

4. Si no está el doctor del repositorio, recopila manualmente solo la evidencia
   que necesite la pregunta. No sustituyas inspecciones fallidas por supuestos.
5. Clasifica cada resultado como fallo, riesgo, aviso u observación. Separa:
   configuración propuesta, estado desplegado y acciones aún no autorizadas.
6. Recomienda el cambio mínimo y reversible. No lo apliques salvo petición
   explícita; para `/etc` o servicios exige destino exacto y copia previa.

## Límites de seguridad

- En Arch/CachyOS usa Pacman o Shelly, nunca `apt`.
- CHWD conserva la propiedad del driver NVIDIA.
- No leas `.env` ni imprimas variables que puedan contener secretos.
- No habilites unidades, cambies parámetros, montes, desmontes ni escribas en
  `/sys`, `/proc`, `/etc` o dispositivos durante la auditoría.
- Usa `pkexec` solo en una fase de aplicación solicitada, no para diagnosticar.
- Consulta [references/checklist.md](references/checklist.md) antes de cerrar.

## Entrega

Resume primero el estado general. Después lista hallazgos por prioridad con su
evidencia, impacto, cambio recomendado y rollback. Termina con pruebas ejecutadas
y riesgos que no pudieron verificarse en el host actual.
