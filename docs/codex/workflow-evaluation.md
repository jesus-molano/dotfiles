# Evaluación del workflow

Los checks estáticos y una ejecución real responden preguntas distintas. CI
valida el catálogo versionado y sus regresiones sin depender del HOME, de un
modelo o de servicios externos. `just codex-runtime-check` revisa el despliegue
actual: nombres únicos, roles requeridos, archivos de agentes y enlaces de skills
vigentes. `just codex-check` combina ambos y revisa la configuración gestionada.

Ejecuta `just ci` y `just lint` en secuencia. Ambas suites prueban Demo Studio con
procesos simulados que se detectan entre sí; ejecutarlas a la vez puede producir
un falso fallo por una grabación ajena.

## Prueba acotada de reutilización

El fixture `scripts/fixtures/codex-reuse` contiene cuatro solicitudes y un
repositorio mínimo de inspección. No es una aplicación compilable: representa
contratos y consumidores. No necesita instalar dependencias ni abrir un servidor.

Ejecutar esta prueba después de cambiar el routing, instrucciones del scout o
despliegue de agentes; no en cada cambio ni automáticamente en CI. Usa una sesión
efímera Luna/low, sandbox de solo lectura, sin historial heredado ni configuración
de MCP/hooks ajenos. Pide al principal que delegue al rol `reuse-scout` por nombre,
sin cambiar su modelo/esfuerzo, y que espere el resultado sin repetir la búsqueda.
La ausencia del rol debe fallar: no sustituirlo por un rol genérico durante la
prueba de descubrimiento. El fallback sigue disponible para trabajo ordinario.

Entrada: ruta del fixture y `cases.md`. No pasar al agente estos criterios ni
respuestas esperadas. Validar después:

| Caso | Evidencia necesaria |
| --- | --- |
| Confirmación con texto secundario | SheetDialog, Text, ActionButton, export público y consumidor CloseAccount; límites de callbacks/estado aún no implementados. |
| Importe decimal | parseAmount, consumidor SavePayment y límites de UI/formato; no crear un segundo parser por defecto. |
| Alternativa nativa en web | Rechazar NativeConfirm para navegador y encontrar SheetDialog; un nombre parecido no basta. |
| Importador CSV inexistente | No inventar un candidato apto; declarar rutas inspeccionadas y capacidades ausentes. |

Además del resultado, comprobar el evento de delegación completada y su receptor.
Una frase como `ROLE_OK` no acredita que se haya ejecutado el rol. Revisar los
contratos y las limitaciones con criterio humano; comprobar rutas por sí solo no
demuestra calidad semántica. Confirmar que el fixture no cambió.

## Resultado del 18-09-2026

Codex CLI 0.155.0 reconoció el rol desplegado como symlink, pero falló al aplicarlo
con `Too many levels of symbolic links`. Con el mismo TOML como archivo regular,
la misma configuración aislada y el mismo prompt, completó una delegación real y los
cuatro casos cumplieron los criterios. Esta prueba motivó el despliegue de agentes
como archivos regulares; las skills mantienen enlaces de carpeta.

Las trazas locales están en
`~/.local/state/dotfiles/codex-workflow-evals/20260918/`: `events.jsonl` conserva
el fallo; `events-regular.jsonl` y `result-regular.json` conservan la ejecución
correcta. No se versionan historiales completos ni datos de productos.

El resultado comprueba descubrimiento y búsqueda en estos cuatro casos. No mide
calidad general del modelo, ahorro económico ni comportamiento de una UI real.
Cuando un fallo real del workflow se repita, convertirlo en un caso mínimo con
un resultado observable y añadirlo aquí; no ampliar el catálogo por intuición.

Fuentes: la [documentación de skills de OpenAI](https://developers.openai.com/es-419/docs/build-skills)
describe el descubrimiento, los enlaces y la convivencia de nombres repetidos.
La [guía de evaluación de agentes de Anthropic](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
fundamenta combinar criterios verificables con revisión de las trazas. El fallo
de roles enlazados procede de la prueba local, no de una afirmación de esas guías.
