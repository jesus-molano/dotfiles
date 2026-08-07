# Flujo Matt Pocock para Codex

Consulta: 2026-08-07. El `main` oficial se verificó en el commit
[`84fdeffd12f2ee307994d1eb6feb48173b6e0502`](https://github.com/mattpocock/skills/commit/84fdeffd12f2ee307994d1eb6feb48173b6e0502).
Esta adopción toma ideas del upstream, pero las skills efectivas siguen siendo
archivos locales versionados: el caché actualizado nunca las sobrescribe.

## Hechos comprobados

- El repositorio presenta sus skills como pequeñas, adaptables, componibles y
  compatibles con distintos modelos. Separa las fases orquestadoras invocadas
  por una persona de las disciplinas que el modelo puede elegir por contexto.
  [Repositorio y referencia del autor](https://github.com/mattpocock/skills#reference)
- El flujo principal publicado por AI Hero es
  `grill-with-docs → to-spec → to-tickets → implement → code-review`; alrededor
  sitúa shaping, mantenimiento y skills de referencia como TDD, diseño de código
  y modelado de dominio. [Mapa oficial de AI Hero](https://www.aihero.dev/)
- Para Codex, el upstream propone copiar una selección editable con
  `npx skills@latest add mattpocock/skills`; esas copias no se actualizan a
  espaldas del usuario y el plugin nativo de Codex sigue anunciado como futuro.
  [Instalación y compatibilidad](https://github.com/mattpocock/skills#installation-30-second-setup)
- Codex descubre skills personales en `$HOME/.agents/skills`, skills de equipo en
  `.agents/skills`, y usa `agents/openai.yaml` para presentación y política de
  invocación. Las instrucciones duraderas y obligatorias pertenecen a
  `AGENTS.md`; una regla más cercana al código prevalece.
  [Skills de Codex](https://learn.chatgpt.com/docs/build-skills),
  [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- Las memorias son contexto local auxiliar; no sustituyen instrucciones
  versionadas ni pruebas. [Memories](https://learn.chatgpt.com/docs/customization/memories)

## Adaptación instalada

Esta tabla es una **decisión local de integración**, no una receta oficial del
autor. El módulo `codex/` despliega las skills en el alcance personal de Codex,
por lo que quedan disponibles en cualquier proyecto; el `AGENTS.md` de cada repo
continúa mandando sobre comandos, riesgos y despliegue.

| Necesidad | Pieza local | Invocación y resultado |
| --- | --- | --- |
| Aclarar una idea | `grill-with-docs` | Explícita; entrevista una decisión cada vez y devuelve un ledger con alcance, alternativas y aceptación. |
| Formalizar alcance | `to-spec` | Explícita; produce una especificación verificable, sin publicarla por su cuenta. |
| Dividir el trabajo | `to-tickets` | Explícita; devuelve tickets Markdown locales y dependencias, sin presuponer GitHub Issues o Linear. |
| Ejecutar un cambio | `engineering-flow` / `implement-ticket` | Explícita; conserva cambios ajenos, valida y pide confirmación inmediatamente antes de cualquier commit. Nunca hace push, deploy o apply por iniciativa propia. |
| Mantener calidad | `test-driven-development` y `systematic-debugging` | Disciplinas automáticas ya existentes, ampliadas con feedback de diseño y evidencia segura; no se instalaron duplicados `tdd` o `diagnosing-bugs`. |
| Diseñar límites | `domain-modeling` / `codebase-design` | Explícitas; profundizan en vocabulario, invariantes, módulos y contratos solo cuando la complejidad lo justifica. |
| Investigar | `research-primary-sources` | Solo lectura por defecto; separa hechos, observaciones e inferencias y devuelve citas actuales. |
| Revisar | `spec-and-standards-review` más `reviewer-spec` y `reviewer-standards` | Explícita y sin escritura; traza por separado especificación y estándares. |
| Dejar contexto | `handoff` | Explícita; devuelve notas de continuidad, pero no mueve chats, worktrees, terminales ni propiedad en Orca. |

`engineering-flow` conecta las fases, pero no obliga a recorrerlas todas. Una
corrección pequeña puede saltar directamente a TDD o diagnóstico; una idea
ambigua debe resolver primero sus decisiones. La separación entre skills
explícitas y automáticas evita que una conversación normal publique documentos
o ejecute una cadena completa sin que se solicite. El diseño, la revisión doble y
las notas de continuidad también son opt-in; TDD, diagnóstico e investigación
primaria conservan activación contextual porque no publican ni despliegan estado.

## Qué se omitió y por qué

- `setup-matt-pocock-skills`, `ask-matt` y el router completo: esta configuración
  ya tiene alcance global, reglas locales y un flujo pequeño conocido.
- `triage` e integraciones de tracker: la decisión es empezar con Markdown local;
  no se inventan etiquetas, permisos ni estados de GitHub/Linear.
- `code-review` literal: se conserva la idea de dos ejes, pero se adapta a una
  skill de revisión y dos agentes Codex de solo lectura.
- Copias nuevas de `tdd` y `diagnosing-bugs`: se fusionaron las ideas útiles en
  las skills maduras que ya existían para evitar disparadores duplicados.
- `grilling` y `writing-for-agents` como skills globales independientes: sus
  reglas útiles viven directamente en `grill-with-docs`, `to-spec`, `to-tickets`
  y `handoff`, donde tienen un consumidor claro y no ocupan dos disparadores más.
- `prototype`, `wayfinder`, `wizard`, automatizaciones de Ralph y operaciones de
  merge: aportan valor en casos concretos, pero amplían superficie, estado o
  riesgo sin una necesidad recurrente demostrada aquí.

La existencia de una carpeta no demuestra que una skill esté lista: debe tener
metadatos válidos, instrucciones terminadas, una política de invocación adecuada
y una prueba de consumo representativa. El repositorio lo comprueba con
`just codex-skills-check`.

## Actualización, caché y trazabilidad

El mantenimiento upstream y la configuración viva son acciones independientes:

- `just codex-upstream-check` valida sin escribir el caché de referencia.
- `just codex-upstream-refresh` actualiza el `main` oficial bajo
  `${XDG_DATA_HOME:-$HOME/.local/share}/codex/upstreams/mattpocock-skills`, valida
  origen, rama, licencia y rutas esperadas, registra el SHA en
  `.dotfiles-upstream.json` y conserva el caché anterior bajo
  `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/codex-upstreams/`.
- `just codex-config-sync` solo intenta sincronizar las preferencias gestionadas
  de Codex; muestra el destino y pide escribir `APLICAR` antes de modificarlo.

No existe un comando compuesto: refrescar la referencia nunca adelanta una
mutación distinta a la que su nombre anuncia. Ninguna receta instala el upstream;
las skills versionadas bajo `codex/.agents/skills/` no cambian hasta que una
persona compara, adapta, prueba y hace commit de una actualización. Si la descarga
o validación falla, el caché anterior permanece. Para validar el caché directamente:

```bash
./scripts/sync-matt-pocock-skills.py --check
```

Seguir `main` aporta una referencia fresca, pero no es reproducible por sí solo;
el SHA registrado es el punto de comparación y revisión. Nunca se ejecutan los
scripts del upstream durante la sincronización.

## X y otras fuentes

La web oficial de Matt enlaza su cuenta como
[`@mattpocockuk`](https://twitter.com/mattpocockuk), pero el contenido de X no
fue accesible de forma estable y reproducible durante esta consulta. No se usó
ningún post como evidencia técnica. X puede dar pistas; las decisiones deben
confirmarse en el repositorio, AI Hero, documentación oficial, un commit o una
fuente primaria equivalente.

## Uso práctico

1. Formula objetivo, contexto, restricciones y condición de terminado.
2. Para una idea ambigua, invoca `$grill-with-docs`; para una tarea clara, elige
   directamente la disciplina necesaria.
3. Lee siempre el `AGENTS.md` aplicable antes de escribir y conserva sus
   validaciones como autoridad.
4. Usa `$to-spec` y `$to-tickets` solo cuando el tamaño lo justifique; los
   borradores permanecen locales salvo autorización expresa.
5. En cambios grandes, invoca explícitamente `$domain-modeling`,
   `$codebase-design` o `$spec-and-standards-review` solo para la fase que lo
   necesite.
6. Antes de commit, muestra el alcance validado y pide confirmación. No añadas por
   iniciativa propia trailers `Co-authored-by` ni atribuyas autoría a agentes.
   Push, despliegue, `apply` y mutaciones externas son autorizaciones distintas.
7. Cierra con pruebas realmente ejecutadas, `git diff --check`, incertidumbres y,
   si queda trabajo, notas compactas mediante `$handoff`.
