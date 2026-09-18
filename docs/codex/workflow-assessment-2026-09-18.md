# Evaluación del workflow: Gentle AI, Matt Pocock y Atlas

Fecha de inspección: 18 de septiembre de 2026. Recomendación: adaptar prácticas
concretas en el flujo existente. No instalar el ecosistema completo de Gentle AI
para resolver un fallo de reutilización y activación de nuestras reglas.

## Comparación y decisiones

| Enfoque | Aportación útil | Coste o límite para este entorno | Decisión |
| --- | --- | --- | --- |
| Gentle AI 3.1 / ODD | Continuidad de una feature, tareas con evidencia y cierre explícito; revisión según riesgo. | Otro protocolo, documentos gestionados y sincronización compiten con nuestras skills y Atlas. Un protocolo escrito no demuestra cumplimiento automático. | Un único registro para cambios sustanciales, actualizable al retomar. Conservar la revisión proporcional existente. |
| Matt Pocock | Skills componibles, requisitos verificables, TDD sobre interfaces públicas y tickets con resultados completos. | Adoptar todo el catálogo duplica capacidades ya adaptadas aquí. Preguntas, specs y arquitectura no deben convertirse en peajes para cada cambio pequeño. | Reforzar tests con valores esperados independientes y pocas simulaciones, slices verticales y migraciones con compatibilidad explícita. |
| Dotfiles antes del cambio | Despliegue reversible, límites de autoridad, verificaciones del catálogo y revisión independiente; Atlas aporta evidencia de reutilización. | La ruta ordinaria no exigía comprobar contratos y consumidores antes de crear UI o lógica. El requisito quedaba demasiado ligado a Atlas. | Regla global, scout ligero, decisión con rutas y revisión del diff final, incluso sin `frontend-task`. |
| Atlas | Candidatos, contratos, consumidores, fuentes de diseño, decisiones bloqueadas y validación del alcance de una tarea compleja. | Preparación, runtime, sidecar y mantenimiento propio; coste fijo excesivo para encontrar un diálogo o helper local. | Mantenerlo selectivo. Consumir su evidencia existente y evitar un segundo análisis paralelo. |

Gentle AI v3.0.0 (16-09-2026) adopta ODD como protocolo predeterminado, con
autorización, exploración, resolución de incertidumbre, clasificación,
seguimiento, implementación y cierre. v3.1.0 (17-09-2026) añade commits por
unidad de trabajo y revisión según riesgo. RDD sigue siendo una opción de
revisión: no es el nombre del protocolo de desarrollo. Adoptamos continuidad y
evidencia; no imponemos un commit por cada checkbox ni una segunda memoria.
Fuentes: [v3.0.0](https://github.com/Gentleman-Programming/gentle-ai/releases/tag/v3.0.0)
y [v3.1.0](https://github.com/Gentleman-Programming/gentle-ai/releases/tag/v3.1.0).

Matt propone skills adaptables, TDD con interfaces públicas y trabajo por
comportamientos. Las mejoras se integran en nuestras skills existentes, sin
instalar su catálogo. El commit `74ca5fe077` consultado corresponde a una limpieza
del documento de PR: no debe citarse como origen de todas las prácticas actuales.
Fuentes: [catálogo oficial](https://github.com/mattpocock/skills),
[TDD](https://github.com/mattpocock/skills/tree/main/skills/engineering/tdd) y
[commit consultado](https://github.com/mattpocock/skills/commit/74ca5fe077).

## Atlas: utilidad y complejidad

La inspección local corresponde al checkout limpio `e703a6a` de
`/home/jesus-molano/dev/project-atlas`. Su protocolo actual conserva valor cuando
hay varias autoridades materiales, contratos compartidos, estados entre rutas,
una migración amplia o una continuación Atlas. No encontramos evidencia para
declararlo obsoleto ni para sustituirlo por una colección de prompts.

El README y las skills actuales describen preflight, preparación de evidencia,
decisión de reutilización, lock y validación posterior. La arquitectura conserva
identidad del checkout y procedencia de los artefactos. Es más control que una
búsqueda local, pero implica Node, pnpm, builds y un almacén propio. La GUI es
opcional; no hay motivo para abrirla para cada implementación.

El perfil MCP activo es `core`, con seis herramientas. El perfil legado de 34
herramientas aún existe: las cifras elevadas de contexto del antiguo audit no
representan el coste del perfil activo. No hemos medido ahorro de tokens,
tiempo o defectos en tareas reales con y sin Atlas; su valor aquí se infiere de
los controles implementados, no de un benchmark.

Hay una deuda concreta de mantenimiento: `scripts/sync-project-atlas.sh` fija
`9bccbde`, diferente del checkout y skills activos. `just atlas-check` falla por
esa divergencia. El doctor completo sí reconoce runtime, builds, skills y
configuración core, y supera el handshake/listado de seis herramientas MCP. El
smoke no ejecuta herramientas ni indexa productos; no verifica una implementación
completa con Atlas. No se debe ejecutar el sincronizador para forzar una versión
sin conciliar primero pin, fuentes, distribución y pruebas. Este cambio preserva
Atlas y corrige la documentación de su activación selectiva.

Evidencia local: `project-atlas/README.md`, `docs/architecture.md`,
`docs/project-atlas-v2-audit.md`, `skills/frontend-task/SKILL.md`,
`skills/reuse-first/SKILL.md`, doctor Linux y sincronizador de dotfiles.

## Búsqueda con modelos ligeros

La búsqueda de candidatos usa modelos ligeros por petición del usuario. La
evaluación de utilidad y complejidad corresponde a Atlas; no implica evaluar
ni restringir el modelo principal elegido para implementar.

| Trabajo | Política aplicada |
| --- | --- |
| Encontrar componentes, funciones, contratos y consumidores | `reuse-scout`: Luna/low, solo lectura y contexto acotado. |
| Resolver una laguna concreta de la búsqueda | Escalar esa pregunta a Terra, sin repetir todo el rastreo. |
| Decidir e implementar | Agente principal con la evidencia del scout, sin repetir el rastreo. |
| Revisión | Independiente y proporcional al riesgo según las reglas existentes. |

## YouTube y X

Se localizaron vídeos del canal oficial:

- [Gentle-AI Course + let's have a chat](https://www.youtube.com/watch?v=QXe4lcjMBhs):
  resultado de unas cuatro semanas antes de la consulta; fecha exacta no verificada.
- [The AI Ecosystem your agent is missing — Engram + SDD + Skills](https://www.youtube.com/watch?v=UoS_LP-PCG8):
  metadatos fechados el 21-03-2026; trata el ecosistema previo a ODD.

La búsqueda acotada no confirmó un vídeo o directo dedicado a ODD 3.x ni un post
verificable de X sobre esa versión. Los vídeos se identificaron por metadatos;
no se atribuyen explicaciones técnicas a contenido que no se ha visto o
transcrito. Las conclusiones sobre ODD proceden de las releases y repositorios.

## Límite de la mejora

Las instrucciones globales cubren la ruta que antes omitía Atlas; la revisión
vuelve a comprobar la decisión. Las pruebas automáticas protegen el contrato del
agente ligero, pero no pueden garantizar que cada futura respuesta obedezca las
instrucciones. La evaluación con Luna sobre tres casos sintéticos verificó
descubrimiento, consumidores y rechazo de una alternativa incompatible; no
sustituye una prueba de implementación en una aplicación real.
