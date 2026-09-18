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

## Verificación de la primera entrega

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

En esa primera entrega, dos comprobaciones amplias conservaron fallos ajenos al delta:

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

## Ampliación autorizada: mantenimiento y revisión general

El usuario amplía el alcance para resolver los fallos conocidos y revisar mejoras
del workflow más allá de Matt Pocock y Gentle AI. Base limpia: `294aa55`.
Las evidencias anteriores se conservan como históricas; esta ampliación necesita
validaciones nuevas. Posteriormente autoriza publicar los cambios al terminar y
comprobar el CI de GitHub. No incluye modificar el modelo principal ni efectuar
mantenimiento ajeno al workflow y sus comprobaciones.

- [x] T7: conciliar fuente, build, skills y pin de Atlas; comprobar su integración.
- [x] T8: diagnosticar y resolver el fallo de Heroic conservando controles útiles.
- [x] T9: auditar duplicados, descubrimiento de skills/agentes y cobertura CI/local.
- [x] T10: contrastar mejoras generales con fuentes primarias y aplicar solo las
  que resuelvan una carencia verificable sin añadir procesos innecesarios.
- [x] T11: revisión independiente, comprobaciones frescas, despliegue necesario y
  commit local; registrar cualquier límite real sin presentarlo como corregido.

Publicación autorizada: `origin/main`. El cierre de la conversación debe acreditar
el OID publicado y la ejecución de GitHub Actions correspondiente a ese mismo OID.

Decisiones y evidencia de la ampliación:

- Heroic ya estaba instalado como `heroic-games-launcher`, reemplazo nativo de
  `heroic-games-launcher-bin`. Se corrigió el manifiesto; no hizo falta instalar.
- Atlas permanece en `e703a6a`. Un export limpio con pnpm 11.9.0 y frozen lockfile
  reprodujo dos veces la huella `f86c547b9cc3aeac0d1e316008f974640ddf530a4186a2a495b844f23c1c2f3b`.
  Las tres skills vendorizadas coinciden y `just atlas-check` pasa.
- Tres backups duplicaban nombres en el catálogo instalado. Se conservaron fuera
  de descubrimiento en `~/.local/state/dotfiles/codex-skills/backups/20260918-atlas-duplicate-catalog/`.
- CI pasa ahora por el validador del catálogo real. El check instalado detecta
  duplicados; el modo `--verify` exige despliegue vigente sin alterar el preflight.
- La prueba real encontró ELOOP al aplicar un rol TOML enlazado. Una copia regular
  idéntica permitió la delegación y los cuatro casos de reutilización. Ver
  `docs/codex/workflow-evaluation.md`. Los cinco roles ya son archivos regulares
  idénticos a su fuente; sus enlaces previos están conservados en
  `~/.local/state/dotfiles/codex-agents/backups/sync-8_zxmd46/`. El nuevo gestor
  registra hashes, actualiza copias propias y preserva ediciones locales.
- La revisión detectó fallos en recuperación concurrente, adopción sin respaldo,
  verificación de copias no registradas y validación temprana del destino. Se
  corrigieron con regresiones específicas. La integración cubre adopción,
  migración de enlaces y archivos ya gestionados con registros Stow antiguos,
  sin modificar los journals históricos.
- `just lint` ya termina con 0 fallos y 0 avisos. El doctor nativo de Codex pasa
  con 19 checks correctos, 0 fallos y 0 avisos en un PTY declarado como
  xterm-256color. Su fallo inicial TERM=dumb correspondía al terminal del runner;
  no se cambió la configuración persistente. Las notas sobre historial y permisos
  describen el estado actual; no justifican borrar sesiones ni cambiar permisos.

Validación final de esta ampliación:

- `just codex-check`: PASS, 93 tests, 19 skills y 5 agentes; verificación del
  despliegue, nombres únicos, configuración y reglas.
- `just ci`: PASS local, incluyendo catálogo versionado y contratos de instalación.
- `just lint`: PASS, 0 fallos y 0 avisos.
- `just atlas-check`: PASS completo; `just check` y `just plan`: PASS.
- Gestor de agentes: migración, actualización de fuente, conservación de ediciones
  locales y concurrentes, fallos de reemplazo/metadatos, recuperación sin respaldo
  válido, rutas fuera de HOME y transferencia de registros Stow anteriores.
- Recuperación manual y retirada: pruebas reales sobre HOME temporal, incluyendo
  checkpoints antiguos, metadatos de agentes y conservación de archivos ajenos.
  El preview del historial vivo supera las comprobaciones de agentes y rechaza
  restaurar otros archivos derivados que cambiaron tras aquella instalación;
  se conserva esa protección y no se intenta una restauración del host.
- Descubrimiento en una sesión nueva: cero entradas de los antiguos backups.
- Delegación real: `reuse-scout` resolvió cuatro casos; el revisor personalizado
  `reviewer-standards` también pudo iniciarse después del despliegue regular.
- Sintaxis de módulos modificados y `git diff --check`: PASS.

La evaluación sintética no acredita una implementación en un producto real. Los
backups y trazas se conservan fuera del catálogo activo para reversibilidad y
auditoría. El resultado remoto se acredita con su ejecución asociada al OID; este
documento registra la verificación local previa a publicar.

Cierre local: hallazgos corregidos, comprobaciones completas y delta listo para
el commit firmado. La publicación autorizada y su CI se acreditan con el OID y
el enlace de ejecución en el cierre de la conversación.
