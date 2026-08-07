# Guía diaria de Codex

## Inicio rápido

1. Abre Codex dentro del repositorio correcto.
2. Describe un único resultado observable.
3. Indica las restricciones que no se pueden deducir del código.
4. Define cómo se demostrará que el trabajo está terminado.
5. Deja que Codex inspeccione el repositorio y seleccione las skills.

Plantilla recomendada:

```text
Implementa <resultado> en <área>.

Reutiliza <componentes, patrones o contratos>.
No cambies <límites importantes>.
Está terminado cuando <comprobación observable>.
```

Ejemplo frontend:

```text
Implementa el filtro de proyectos en la vista principal.

Reutiliza los componentes y tokens existentes.
No cambies el contrato de la API.
Incluye carga, vacío, error y navegación por teclado.
Verifica tipos, pruebas y el flujo real en navegador.
```

## Elige el verbo correcto

- `Implementa`: autoriza cambios y una verificación completa.
- `Diagnostica, no modifiques`: busca la causa y aporta evidencia.
- `Revisa contra main`: busca fallos sin escribir archivos.
- `Diseña`: define límites, contratos o arquitectura antes de implementar.
- `Investiga con fuentes oficiales`: comprueba información que puede cambiar.

No mezcles diagnóstico, implementación y revisión en una petición ambigua.

## Perfiles

```bash
codex              # Selección activa; uso normal
codex -p fast      # Terra medium
codex -p deep      # Sol high
codex -p ultra     # Sol ultra
```

- Usa la selección normal para la mayoría del desarrollo.
- Usa `fast` para búsquedas, documentación y cambios mecánicos.
- Usa `deep` para bugs difíciles, arquitectura y revisiones importantes.
- Usa `ultra` solo para decisiones excepcionales con riesgo o ambigüedad alta.

El sincronizador conserva el modelo y el razonamiento que elijas en Codex.

## Routing de skills

Codex activa automáticamente las skills comunes a partir de la intención del
prompt. No necesitas memorizar sus nombres.

- Implementación ordinaria: `engineering-flow`.
- Diagnóstico general: `systematic-debugging`.
- Flujo web entre navegador y servidor: `debug-web-flow`.
- Ambigüedad material: `clarify-change`.
- Investigación técnica actual: `research-primary-sources`.
- Revisión web: `review-web-pr`.
- Revisión de requisitos o estándares: `spec-and-standards-review`.
- Evidencia final: `verification-before-completion`.
- Continuación en otra sesión: `handoff`.

Usa una skill explícita cuando quieras imponer ese proceso:

```text
$frontend-task Implementa el ticket ATLAS-123.
$reuse-first Comprueba si ya existe un componente adecuado.
$visual-direction Define la autoridad visual antes de diseñar.
$test-driven-development Implementa esta regla con un ciclo rojo-verde.
$verify-web-change Verifica este flujo real en navegador.
```

No invoques varias skills por precaución. Cada skill añade instrucciones y
consume contexto cuando se carga.

## Evita IA slop en frontend

- Indica la fuente de verdad: Figma, ticket, componente, ruta o contrato.
- Exige reutilizar componentes, tokens y patrones existentes.
- Define los estados `loading`, vacío, error, éxito y deshabilitado que apliquen.
- Incluye responsive, foco visible, teclado y semántica accesible.
- Pide que no invente copy, iconos, animaciones o componentes sin autoridad.
- Solicita evidencia visual o de navegador cuando el comportamiento sea visible.
- Separa una propuesta visual nueva de una implementación basada en diseño.

Prompt útil:

```text
Antes de crear UI, identifica la autoridad visual y los componentes reutilizables.
No inventes nuevos patrones si el repositorio ya resuelve el mismo problema.
```

## Reduce tokens y ruido

- Usa una sesión por objetivo independiente.
- No pegues el repositorio ni logs completos. Da el error y permite la inspección.
- Aporta contexto que Codex no puede descubrir: intención de producto y límites.
- Evita instrucciones de estilo repetidas. `AGENTS.md` ya contiene las duraderas.
- Pide un `handoff` si pausas un trabajo complejo.
- Usa subagentes solo para tareas independientes o una revisión con valor real.
- Prefiere un criterio de aceptación concreto a frases como «hazlo mejor».

## Preguntas y autonomía

Codex debe inspeccionar antes de preguntar. Debe resolver de forma autónoma las
decisiones locales, reversibles y verificables.

Una pregunta es útil cuando la respuesta cambia:

- producto o datos;
- seguridad o compatibilidad;
- coste o despliegue;
- autoridad para actuar;
- una operación irreversible.

Responde esas preguntas con la decisión y la razón. No necesitas describir la
implementación interna.

## Cierre de una tarea

Antes de aceptar un resultado, comprueba que Codex indique:

- qué cambió;
- qué pruebas ejecutó y su resultado;
- qué no pudo verificar;
- qué riesgo residual permanece.

Una implementación verificada puede producir un commit local coherente. El push
requiere una petición explícita y publica solo el OID verificado. Nunca se añaden
trailers `Co-authored-by`.

## Mantenimiento de esta configuración

```bash
just codex-check       # skills, agentes, pruebas, enlaces y configuración
just atlas-check       # Project Atlas y sus tres skills explícitas
just codex-config-sync # fusiona preferencias estables con backup
```

El sincronizador conserva hooks de Orca, MCP, trusts y claves ajenas. No actúa
como daemon y no intercepta Git.

## Referencias

- [Modelo operativo](operating-model.md)
- [Acuerdo global](../../codex/.codex/AGENTS.md)
- [Plantilla de configuración](../../codex/.codex/config.template.toml)
- [Skills de Codex](https://learn.chatgpt.com/docs/build-skills)
- [Configuración de Codex](https://learn.chatgpt.com/docs/config-file/config-reference#configtoml)
