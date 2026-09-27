# Codex y Claude: integración compartida

## Contrato

Implementación autorizada: conservar Codex, añadir Claude Desktop Extra + CLI
en CachyOS y preparar Claude Desktop oficial en Windows nativo. Pro/Max,
español, bypass técnico con los límites humanos actuales de publicación y datos.
Selector local Claude por defecto. Atlas se retira como integración, conservando
checkout, datos y apariencia. No incluye Cowork ni activar control del ordenador.

## Reutilización

- Extender `sync-codex-config.py`, el catálogo y los gestores de agentes/skills.
- Componer los helpers `hypr-chatgpt`, `project-session`, `capture-context`,
  `desktop-launcher` y `desktop-notify` con un resolvedor de proveedor.
- Crear sincronizador portable: los gestores actuales solo despliegan Codex en
  Linux y no resuelven copias Windows ni configuración JSON de Claude.

## Trabajo y aceptación

- A1: fuente neutral, adaptación de skills/roles, retirada activa de Atlas.
- A2: sincronizador con plan/check/apply/rollback, backups y preservación local;
  PowerShell, pruebas portables y CI Windows.
- A3: selector, foco, capturas, proyectos, arranque y fallback CLI comprobados.
- A4: paquetes revisados, despliegue local, descubrimiento real y guía diaria.
- A5: verificaciones finales, revisión independiente y commit local.

## Evidencia inicial

`main` limpio. En la planificación pasaron `just lint` y `just codex-check`
(93 pruebas, 19 skills, 5 roles). Repetir sobre el delta final.
El doctor vivo detectó una diferencia previa entre la base importada CachyOS
1.2.5 y el paquete 1.2.6; se registra aparte de esta integración.
No hay un Windows accesible: las pruebas GUI del ordenador del trabajo deberán
ejecutarse allí. No se publicará sin autorización del OID/destino exactos.

## Planes anteriores incorporados como contexto

El ZIP aportado contiene `plan-claude-codex-config.md` y `plan-tessera-jev.md`.
Coinciden en fuente neutral, adaptadores pequeños, continuidad en archivos y
preservación de estado privado. Su propuesta de Tessera/JEV y visual-direction
independiente se documenta en `docs/ai.md` para una fase posterior. El usuario
confirmó explícitamente terminar primero Claude/Codex. No se amplía esta entrega.

## Entrega local verificada (2026-09-27)

- A1: fuente `ai/`, 16 skills propias y Playwright CLI 0.1.21, cinco roles por
  cliente. Se retiraron MCP, tres skills, sincronizador y colección QMD de Atlas.
  El checkout y los temas siguen presentes.
- A2: sincronizador portable, copias Windows por archivo, reemplazos atómicos,
  conflictos, recuperación de interrupciones, backups y rollback probados.
  Segunda aplicación real: `OK: sin cambios`; comprobación: cero pendientes.
  Las claves de modelos, esfuerzo, conexiones y hooks ajenos se conservan.
- A3: Claude es el proveedor local. Arranque repetido de ambas aplicaciones sin
  duplicar ventanas; cambiar la preferencia conserva las ventanas y sesiones;
  foco real de ambos clientes comprobado. Proyectos, captura y fallback al CLI
  pasan las pruebas con ejecutables simulados. Una captura real con una imagen
  de prueba produjo imagen y contexto; su lectura posterior del portapapeles de
  un solo uso no se pudo confirmar. Región interactiva/Satty quedan como prueba
  manual de uso, sin afirmar que se hayan validado en esta entrega.
- A4: instalados Claude Code 2.1.283-1 (CachyOS) y Desktop Extra 2.7032.0-3
  (AUR revisado, construcción Shelly, instalación Pacman). CLI autenticado con
  suscripción Max. Desktop muestra Code y `Bypass permissions`, activado por su
  ajuste documentado. Se conserva su elección local de modelo/esfuerzo.
- En una sesión nueva de Claude se descubrieron las 17 skills propias/vendor,
  los cinco roles, `bypassPermissions` y el MCP OpenAI Docs conectado. Linear
  de lectura devuelve `needs-auth`; falta completar su OAuth en Claude.
  Ambos CLI respondieron en español y reconocieron las reglas de reutilización,
  commit local y publicación. Claude también reconoció el `AGENTS.md` del repo.
- Playwright abrió una página HTTP local aislada con Brave headless y comprobó
  un botón que pasó a «Verificado». Navegador y servidor de prueba cerrados.
  Notificaciones genéricas de ambos CLI observadas en el escritorio.
- A5: revisión independiente de sincronizador y escritorio, dos pasadas por
  área. Se corrigieron sus hallazgos y se añadieron regresiones. La última revisión
  de escritorio no encontró nuevos problemas; las correcciones del sincronizador
  tras su segunda revisión se comprobaron con pruebas, sin una tercera revisión.

## Validación y límites

- `just ai-check`: 128 pruebas Python; pasa, con una prueba de junction exclusiva
  de Windows omitida en Linux. Incluye migración, copias con espacios, idempotencia,
  conservación de claves, conflictos, interrupciones y rollback.
- `just ci`: suite portable completa superada. Después se añadió la regresión
  de sustitución atómica de enlaces, validada con `just ai-check`.
- `just lint`: cero fallos y cero avisos; `just check`, `just plan`, generación de
  adaptadores y comprobaciones Git superadas. Hyprland no informa errores activos.
- Job Windows añadido a CI, todavía sin ejecución remota. Desktop oficial,
  políticas corporativas, PowerShell y comportamiento nativo deben verificarse
  en el ordenador Windows del trabajo. No se presentan como pruebas realizadas.
- `just doctor-live` no está limpio: persiste la diferencia previa de base
  CachyOS importada 1.2.5 frente a paquete 1.2.6 (cinco checksums). Además, el
  diagnóstico final detecta `mnt-backups.mount` y `restic-backup.service` fallidos.
  No se cambiaron ni repararon estos componentes como parte de la integración.

## Respaldos de este despliegue

Ubicaciones locales; contienen estado privado y quedan fuera de Git:

- AI inicial: `~/.local/state/dotfiles/ai/backups/20260927-214407-4a41d459`.
- Ajustes posteriores: `20260927-214505-45d4a7b1` y
  `20260927-214641-c1b1b0fc`, bajo el mismo directorio.
- Stow inicial: `~/.local/state/dotfiles/migrations/deployment-20260927-214704.xHJy9c`.
- Stow final: `~/.local/state/dotfiles/migrations/deployment-20260927-215919.aS8JIy`.

Los respaldos se restauran en orden inverso y con comprobación de modificaciones
posteriores. No se ha publicado el cambio remoto. La guía de uso, recuperación,
Windows y cambio mensual está en `docs/ai.md`.
