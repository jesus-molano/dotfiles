# Prompt: auditar un flujo Matt Pocock para Codex

Úsalo en otra sesión de Codex. Está diseñado para hacer el estudio desde cero;
no presupone esta máquina, este repositorio, sistema operativo, configuración ni
conclusiones anteriores.

```text
Realiza desde cero una auditoría del workflow público de Matt Pocock para
decidir qué ideas o skills merece la pena adoptar, adaptar, fusionar u omitir en
este ordenador y sus repositorios con Codex. Investiga su GitHub, su repositorio
de skills, su web/AI Hero, su X público y las demás fuentes oficiales relevantes;
no partas de una selección ni de conclusiones anteriores.

Límites no negociables:
- No modifiques archivos, configuración, Git, paquetes, plugins, skills ni
  servicios. No ejecutes instaladores, sincronizaciones ni comandos de
  actualización, incluido nada con `latest`.
- Para inspeccionar un repositorio público puedes clonarlo únicamente dentro de
  un directorio temporal aislado creado de forma segura. No ejecutes sus scripts,
  hooks ni instaladores, no copies nada al proyecto o a Codex y registra el SHA
  exacto estudiado.
- No abras, muestres, copies ni resumas `.env`, archivos de credenciales,
  tokens, claves o almacenes de secretos. Si una ruta parece sensible, omítela
  y dilo sin revelar su contenido.
- No supongas el sistema operativo, el shell, el gestor de paquetes, Codex,
  permisos, tracker, MCP, modelo, directorio de configuración ni que un skill
  disponible sea compatible. Inspecciona únicamente lo necesario y de forma
  segura para esta máquina.
- No heredes conclusiones, selecciones ni comandos de estudios previos.

Método:
1. Lee las instrucciones aplicables del repositorio y comprueba el estado Git
   sin cambiarlo. Identifica las comprobaciones locales y qué acciones serían
   de alto impacto.
2. Haz inventario no destructivo del sistema operativo, shell, versión y
   superficies de Codex, configuración aplicable, `AGENTS.md`, skills globales y
   del repositorio, agentes personalizados y scripts de validación. Resume solo
   estructura y claves relevantes; nunca vuelques configuración completa.
3. Investiga desde cero con fuentes primarias actuales:
   - el perfil de GitHub de Matt Pocock y los repositorios, README, skills,
     commits, tags/releases y licencia que realmente resulten relevantes;
   - `mattpocock.com`, AI Hero y sus artículos o vídeos oficiales cuando aporten
     diseño o contexto al workflow;
   - el perfil público de X enlazado por el propio autor y publicaciones
     relevantes que sean accesibles sin iniciar sesión; si X bloquea el acceso,
     registra la limitación y no intentes eludirla;
   - la documentación oficial actual de Codex sobre `AGENTS.md`, skills,
     `agents/openai.yaml`, agentes personalizados, configuración y seguridad.
   Consulta cada fuente durante esta auditoría y anota fecha, URL y, para Git,
   SHA. Usa X como pista o declaración atribuida, no como prueba única de una
   recomendación técnica; confirma las conclusiones en una fuente más estable.
4. Reconstruye el workflow del autor: problema que resuelve cada fase, orden,
   disparador humano o automático, entradas/salidas, estado que escribe,
   feedback loops y puntos de revisión humana. Distingue lo que el autor afirma
   de tu inferencia.
5. Compara ese mapa con el inventario local. Detecta solapamientos y conflictos,
   especialmente TDD, diagnóstico, planificación, revisión, handoff, trackers,
   permisos y despliegue. Distingue una carpeta existente de una skill válida,
   terminada, visible y realmente disparable por esta instalación de Codex.
6. Propón una selección mínima con decisión `adoptar`, `adaptar`, `fusionar` u
   `omitir`. Para cada pieza explica propósito, disparador, entrada/salida,
   compatibilidad comprobada, adaptación, validación y riesgo. No inventes un
   tracker, etiquetas, permisos, rutas o una cadena de trabajo no respaldada por
   evidencia. Si una preferencia material no se puede deducir de la máquina o
   del repositorio, pregunta al usuario después de investigar, no antes.
7. Evalúa cualquier sincronización local de Codex por sus efectos reales:
   destino exacto, claves que cambia, qué preserva, confirmación, backup y
   rollback. No la ejecutes. Advierte si una configuración puede ser
   específica de la máquina.

Entrega un informe Markdown con: resumen ejecutivo; inventario local relevante;
fuentes y limitaciones; workflow reconstruido; matriz comparativa
`upstream/local/decisión/razón/riesgo`; flujo recomendado para esta máquina;
omisiones; estrategia de actualización; y un plan de implementación reversible
con archivos, comandos de validación y rollback propuestos. Separa siempre
(a) hechos citados, (b) observaciones locales y (c) inferencias. Termina
diciendo si recomiendas no cambiar nada, una prueba manual aislada o una
propuesta revisable, y pide autorización antes de cualquier escritura. No hagas
cambios durante la auditoría.
```
