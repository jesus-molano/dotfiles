# Reutilización en el flujo normal de Codex

## Objetivo y alcance

Evitar UI y funcionalidad duplicadas, incluso fuera de `frontend-task`, mediante
búsqueda ligera, decisión con evidencia y verificación del resultado. Integrar
continuidad y mejoras de pruebas/tickets sin instalar catálogos externos.
Evaluar además la utilidad y complejidad actual de Atlas.
No incluye cambios en aplicaciones de producto, publicación ni retirada de Atlas.

## Tareas

- [x] T1: inspeccionar reglas y rutas activas. El flujo ordinario carecía de una
  comprobación explícita; Atlas ya tenía una y no necesita otra tarea paralela.
- [x] T2: añadir búsqueda, decisión y revisión de reutilización al flujo normal,
  incluyendo diálogos, tipografía, wrappers, tokens y funcionalidad compartida.
- [x] T3: configurar y comprobar el rastreo con Luna, solo lectura, sin heredar
  el historial completo; escalar únicamente lagunas concretas a Terra.
- [x] T4: reforzar continuidad, tests por comportamiento y tickets verticales.
- [x] T5: evaluar Atlas con evidencia y registrar recomendaciones.
- [x] T6: verificar escenarios de uso, checks del repo y despliegue efectivo;
  revisión independiente del delta para commit local.

## Decisiones

Se amplían `engineering-flow`, sus referencias y las comprobaciones existentes.
`reuse-first` y `frontend-task` siguen bajo propiedad de Atlas. No se añaden
MCP, Engram ni un segundo catálogo. El principal decide; el scout busca.
Las reglas globales cubren implementaciones que no lleguen a cargar una skill.

## Evidencia y siguiente paso

Estado inicial: dotfiles limpio en `f46871648b3306ace2a52cf018acbdbd8a85a8b4`.
Las skills ordinarias y AGENTS global se consumen mediante enlaces canónicos.
Atlas activo está en `e703a6a`; el sincronizador fija `9bccbde`: divergencia
preexistente que debe evaluarse sin sobrescribir el checkout activo.
Evaluación completa en `docs/codex/workflow-assessment-2026-09-18.md`: conservar
Atlas selectivo y usar Luna para rastreo. La aclaración posterior del usuario
excluye la evaluación del modelo principal; su elección permanece intacta.

El agente Luna, con instrucciones de `reuse-scout` y sin historial heredado,
evaluó tres casos en `/tmp/codex-reuse-eval-d_rv10q3`: confirmó los contratos de
SheetDialog/Text/ActionButton y su consumidor; encontró parseAmount y su uso,
advirtiendo límites del formato; rechazó NativeConfirm de React Native para web.
Es una evaluación sintética de descubrimiento, no de integración en navegador
ni de carga automática del rol. El TOML se desplegó mediante Stow solo para
`codex`, después de `just check`, `just plan` y simulación exacta (un único enlace
nuevo). Las reglas y skills existentes ya tienen enlaces a fuentes canónicas.
La disponibilidad del rol por nombre debe comprobarse al iniciar una sesión
nueva; el fallback explícito de modelo sí se ejercitó aquí.

Una revisión independiente detectó y corrigió la posible duplicación del scout
cuando Atlas ya tiene evidencia, y la ausencia de una exigencia del rol en el
checker. La receta canónica ahora exige `--required-agent reuse-scout`. El
segundo pase cerró ambos hallazgos sin incidencias pendientes.

## Verificación final

Delta comprobado sobre `f46871648b3306ace2a52cf018acbdbd8a85a8b4`:

- `just codex-check`: PASS, 19 skills, 5 agentes y 67 tests; enlaces, configuración
  gestionada y ausencia de reglas temporales obsoletas correctos.
- `quick_validate.py` del creador de skills: PASS para las siete skills editadas.
- `just check`: PASS de simulación hermética y validaciones de componentes.
  Noctalia emite siete advertencias de plugins externos no cargados en HOME temporal.
- `just plan`: PASS, preflight sin cambios. La simulación específica de Stow
  para `codex` solo añadió el enlace de `reuse-scout.toml`; aplicado y resuelto
  posteriormente a la fuente canónica.
- Doctor de Atlas completo: PASS, incluido handshake y listado MCP core de seis
  herramientas. No ejecuta tareas de producto ni verifica su implementación.
- Revisión independiente: segundo pase sin hallazgos pendientes.
- `git diff --check` y `git diff --cached --check`: PASS.

Dos comprobaciones amplias conservan fallos ajenos a este delta:

- `just lint`: falta `heroic-games-launcher-bin` requerido por gaming-launchers.
- `just atlas-check`: el pin `9bccbde` no coincide con el clone activo `e703a6a`.

No se instalaron paquetes ni se alteró Atlas para ocultar estos resultados.
Atlas permanece limpio en su OID inicial. La carga del nuevo rol por nombre en
una sesión nueva sigue sin probarse; se verificaron configuración, despliegue y
el mismo contrato con una delegación Luna explícita. No se probó la integración
de UI en una aplicación real.

Entrega: commit local coherente del delta, identificable con
`git log -1 -- docs/work/codex-reuse-workflow.md`; publicación no solicitada.
No queda trabajo de implementación en este alcance. El pin de Atlas es una
deuda de mantenimiento separada que exige conciliar sus artefactos antes de sync.
