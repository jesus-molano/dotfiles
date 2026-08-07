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
| Dividir el trabajo | `to-tickets` | Explícita; devuelve primero tickets Markdown locales y dependencias. Una publicación posterior requiere `$linear`. |
| Consultar o actualizar el tracker | `linear` | Explícita; lee primero y solo crea o modifica objetos tras previsualizar el lote y recibir autorización concreta. |
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
las notas de continuidad y Linear también son opt-in; TDD, diagnóstico e
investigación primaria conservan activación contextual porque no publican ni
despliegan estado.

## Qué se omitió y por qué

- `setup-matt-pocock-skills`, `ask-matt` y el router completo: esta configuración
  ya tiene alcance global, reglas locales y un flujo pequeño conocido.
- `triage` autónomo y automatizaciones masivas del tracker: Linear se integra de
  forma estrecha y explícita, pero no se inventan etiquetas, permisos, equipos ni
  estados, ni se publica un borrador sin una confirmación inmediatamente previa.
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

## Linear: asociación sin automatismo peligroso

La skill local `$linear` adapta la
[`linear` oficial de OpenAI](https://github.com/openai/skills/tree/49f948faa9258a0c61caceaf225e179651397431/skills/.curated/linear)
fijada al commit `49f948faa9258a0c61caceaf225e179651397431` y conserva su
licencia Apache-2.0. La conexión usa el
[MCP oficial de Linear](https://linear.app/docs/mcp) con OAuth; no hay tokens ni
identificadores del workspace en el repositorio.

El servidor `linear` usa `/mcp/readonly`, de modo que una sesión normal carece de
herramientas de mutación. `linear-write` usa `/mcp` porque el objetivo incluye
publicar tickets autorizados, pero queda deshabilitado en la configuración base.
Cuando se activa expresamente para una sesión, el gate de la skill vuelve a ser
una salvaguarda de procedimiento y por eso su alcance debe limitarse al lote ya
revisado.

La configuración personal se añade al `config.toml` vivo, que Orca también usa:

```bash
codex mcp add linear --url https://mcp.linear.app/mcp/readonly
codex mcp login linear
codex mcp add linear-write --url https://mcp.linear.app/mcp
codex mcp login linear-write
codex mcp list
```

Después del alta OAuth, el bloque `[mcp_servers.linear-write]` se deja con
`enabled = false`. Hay que iniciar una sesión nueva de Codex para que descubra el
MCP y la skill desplegada. `just codex-config-sync` conserva las secciones
`mcp_servers.*`; `just codex-check` ejecuta una regresión que cubre expresamente
los dos servidores Linear y Component Atlas. `config.template.toml` contiene
solo un ejemplo comentado, no credenciales ni una instalación automática.

El flujo efectivo separa permisos:

1. `$to-tickets` genera y permite revisar borradores locales.
2. `$linear` consulta el equipo, proyecto, estados y posibles duplicados vivos.
3. La sesión de lectura prepara un preview provisional, pero no pide ni conserva
   la autorización final.
4. Para publicar se abre una sesión efímeramente capaz de escribir:
   `codex -c 'mcp_servers.linear-write.enabled=true'`. El override no persiste.
5. La sesión nueva recibe el preview, relee los objetos, reconcilia cambios,
   muestra el lote actualizado y pide una confirmación fresca.
6. `$linear` crea o actualiza solo el lote recién confirmado, relee los IDs
   resultantes y comunica cualquier éxito parcial.
7. `$implement-ticket JRL-123` puede leer ese issue como contrato, pero no cambia
   su estado ni publica comentarios por haber implementado, validado o hecho
   commit. Esas mutaciones requieren otra autorización.

Si está habilitada la
[integración GitHub de Linear](https://linear.app/docs/github-integration), incluir
la clave del issue en la rama o en el título de la PR permite asociarlos. Esto no
autoriza crear rama, commit, push o PR, y el vínculo debe comprobarse después.

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
   borradores permanecen locales. Invoca `$linear` para consultar o preparar su
   publicación y confirma el lote exacto inmediatamente antes de escribir.
5. En cambios grandes, invoca explícitamente `$domain-modeling`,
   `$codebase-design` o `$spec-and-standards-review` solo para la fase que lo
   necesite.
6. Antes de commit, muestra el alcance validado y pide confirmación. No añadas por
   iniciativa propia trailers `Co-authored-by` ni atribuyas autoría a agentes.
   Push, despliegue, `apply` y mutaciones externas son autorizaciones distintas.
7. Cierra con pruebas realmente ejecutadas, `git diff --check`, incertidumbres y,
   si queda trabajo, notas compactas mediante `$handoff`.
