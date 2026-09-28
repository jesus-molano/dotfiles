# Contrato Tessera v1

## Propiedad y separación

Tessera es tooling personal. Cada proyecto tiene un catálogo e historial
independientes, guardados fuera de los repositorios Git por defecto:

- Linux: `${XDG_DATA_HOME:-~/.local/share}/tessera/projects/<id>/`.
- Windows: `%LOCALAPPDATA%\tessera\projects\<id>\`.

`tessera.py locate --repo PROJECT` resuelve esas rutas sin crear archivos.
Contienen `catalog.json`, `inventory.json`, `history/`, `tasks/`, `runs/` y `decisions/`. El ID es
un hash de la ruta local real de `git-common-dir`: worktrees enlazados comparten
conocimiento; clones independientes tienen almacenes separados. No usa remotos,
credenciales ni un archivo de identificación dentro del proyecto. Mover o
reclonar el checkout cambia el ID: recuperar/revisar el catálogo de forma
explícita, sin copiarlo automáticamente entre equipos o empresas.

En proyectos del trabajo no se crea `.tessera`, no se modifica `.gitignore` y
no se versionan fichas ni decisiones. Tampoco se copian a dotfiles/GitHub
personal. Dotfiles distribuye scripts y skills; los datos permanecen en el PC
del trabajo. No hay sincronización de catálogos entre ordenadores. Un traslado
requiere petición explícita y un destino autorizado. Compartir un catálogo en
un repo es una excepción explícita, no el valor predeterminado.

`prepare` rechaza catálogo, tarea o salida dentro de cualquier checkout Git;
`evaluate` vuelve a comprobar la ubicación del run antes de escribir o llamar
al proveedor, incluso si se llega mediante un enlace. `--allow-repo-storage`
se exige en cada invocación afectada y permite únicamente
un flujo de compartición expresamente autorizado. La detección usa los marcadores
de checkout `.git`; no es un sandbox ni un sistema de clasificación de datos.
No usar la excepción para proyectos del trabajo.

`ai/tessera/pilots/expenses-log-app` es el piloto personal previamente publicado,
no un patrón para almacenar información de empresa ni un despliegue en la app.

| Capa | Contenido | Propietario |
|---|---|---|
| Catálogo curado | Responsabilidad, contrato, restricciones, fuentes y usos | Proyecto y sus agentes |
| Evidencia derivada | Inventario, contenido de fuentes, hashes, revisión | `prepare`, regenerable |
| Contexto neutral | Tarea, fichas completas, procedencia y opciones; sin archivos completos | Tessera |
| Intercambio externo | Petición/respuesta específica, autenticación | Adaptador de proveedor |
| Decisión | Acción, identidad, procedencia, explicación atribuida y resultado | Proyecto |

No guarda memoria conversacional, planes de trabajo ni referencias de inspiración.
No usa Atlas, una base vectorial, Figma ni un servidor.

El [ciclo de vida](lifecycle.md) define `status`, `init`, `scan`, `review` y
`finalize`: cobertura del árbol Git sin tests, revisión reanudable y vigencia.
`current` en `changes` describe las fichas del ámbito; solo `ready` en `status`
acredita inventario revisado y catálogo finalizado. El flujo habitual prepara
con `--require-ready`. Un piloto antiguo sin inventario requiere revisión completa.

## Catálogo y crecimiento

JSON UTF-8 con `schema: 1`, `project`, `scope` y `entries`. `scope` enumera rutas
relativas de archivos o directorios del proyecto. En directorios se inventarían
los archivos salvo tests y artefactos de pruebas, excluidos por ruta antes de
leer contenido según [lifecycle](lifecycle.md).
No hay lista de lenguajes admitidos ni filtro de relevancia. Usar ámbitos de
fuentes concretos; no incluir HOME, dependencias, datos de usuarios o secretos.

Cada ficha contiene:

- `id`: estable, minúsculas y guiones; independiente del proveedor y del checkout.
- `name`, `tags`: opcionales; nombre de exports y conceptos que ayudan a descubrir.
- `kind`, `summary`, `contract`: naturaleza, responsabilidad y API/comportamiento.
  Explicitar entradas, salidas, efectos y dependencias relevantes al contrato.
- `constraints`: restricciones y garantías ausentes; lista explícita.
- `source`: archivo que implementa el contrato. Una ficha puede describir varios
  exports de ese archivo. El piloto usa una ficha por archivo de implementación.
- `usages`: objetos `path`, `start`, `end`, con líneas inclusivas de un uso real.
  Si no se encuentran consumidores, admite `[]` con `usage_gap` textual que
  explique la búsqueda o uso implícito del framework. No inventar un consumidor.
- `tests`: campo antiguo opcional; se ignora sin abrir ni resolver sus rutas y
  no se envía al proveedor. Omitirlo en fichas nuevas. Las pruebas quedan fuera
  de fuentes, usos, soporte y decisiones de Tessera.

`supporting_files` opcional enumera rutas de tokens, estilos o manifiestos para
la inspección local. `derived.json` conserva los archivos completos y hashes.
El proveedor recibe fichas, referencias y estado de curación, no los archivos.
Las rutas no conceden acceso: ni Jev ni otro motor remoto puede abrirlas.
Si falta un dato para decidir, el agente inspecciona la fuente y enriquece el
contrato o las restricciones antes de preparar otro run. No se recortan fichas
ni se sube el código completo automáticamente.
`coverage` y `reviewed_revision` documentan alcance y revisión humana/agente.
Un proyecto sin piezas catalogables puede tener `scope: []` y `entries: []`;
la revisión de todos sus archivos y exclusiones sigue siendo necesaria para
finalizarlo. `kind` es una clasificación semántica extensible, asignada por el
agente leyendo código y consumidores, no por un detector de nombres de archivo.
Todas las rutas son relativas al proyecto. El helper rechaza escapes, enlaces,
`.env*`, campos desconocidos, evidencia no versionada, IDs repetidos y diferencias entre ámbito y fichas.
La evidencia local registra archivos completos, no solo rangos de uso; deduplica
por ruta. La petición compacta no contiene esos textos.
`evidence.curation.status` distingue `current` si las fuentes coinciden con la
revisión curada, `stale` si cambian o no se puede resolver esa revisión, y
`unverified` si falta. Un commit ajeno al ámbito no invalida las fichas: se
comparan los árboles Git de las rutas de evidencia. `evaluate` rechaza `stale` antes del envío.
Revisar también la semántica y actualizar `reviewed_revision` tras curar cambios.

Para incorporar un componente/utilidad: inspeccionar contrato y consumidor,
añadir ficha, ampliar ámbito si corresponde, registrar usos reales o gaps, ejecutar
`prepare` y revisar el diff. Un candidato nuevo en un ámbito ya declarado causa
error de cobertura hasta curarlo. No queda oculto por ranking. La primera versión
prepara evidencia de un checkout limpio; después de implementar, verificar y
crear el commit local coherente antes de regenerar el snapshot.

### Cambios de compañeros y actualización

Antes de cada decisión, `tessera.py changes --repo PROJECT` compara el checkout
con `reviewed_revision`. Informa de fuentes nuevas/eliminadas, rutas cambiadas,
referencias desaparecidas, fichas afectadas y cambios sin commit. Los renombrados
aparecen como baja y alta, que el agente debe reconciliar conservando identidad
si corresponde. También devuelve cambios fuera del catálogo, sin decidir por
nombre cuáles son relevantes, para inspeccionar posibles ampliaciones.

El agente lee los cambios, actualiza el significado de las fichas y guarda una
copia previa bajo `history/`; solo después actualiza `reviewed_revision` y
`reviewed_on`. Añadir un componente en el ámbito exige curar su ficha. Una
revisión ausente/desconocida exige revisar el catálogo completo. Cambios ajenos
a sus fuentes no invalidan automáticamente las fichas existentes.

Esto sucede al trabajar y consultar el catálogo, incluidos cambios incorporados
con pull o cambio de rama. No hay watcher ni consulta automática a GitHub.
Los compañeros no necesitan instalar Tessera. `prepare` sigue exigiendo fuentes
versionadas y checkout limpio; `evaluate` vuelve a capturar la evidencia antes
de la red y rechaza un snapshot que haya cambiado. Un run antiguo sin referencia
local al checkout debe prepararse de nuevo. Las rutas locales del manifiesto
no se envían al proveedor.

## Contrato neutral de decisión

`context.json` contiene `schema`, `task`, `catalog`, `evidence`, `options` e
`instructions`. Tarea: `id`, `requirement` y lista no vacía `acceptance`.
El catálogo completo declarado está disponible en cada evaluación. `evidence`
solo comunica revisión, estado de curación y `source_text_included: false`.
Los textos completos permanecen en `derived.json`, separado del contexto neutral.
Se verifica su hash y se reconstruye el contexto antes de enviar la petición.

Opciones comunes, independientes del modelo:

| Acción | Significado |
|---|---|
| `reuse:<id>` | Consumir el contrato existente sin cambiarlo |
| `modify:<id>` | Cambiar implementación o contrato y verificar sus consumidores |
| `wrap:<id>` | Componer una envoltura para la tarea conservando la base |
| `create` | Nueva implementación principal; puede reutilizar primitivas auxiliares |
| `insufficient_evidence` | Falta contexto para elegir con fundamento |

El primer piloto decide una responsabilidad principal por tarea. Una tarea con
varias responsabilidades necesita explicitar esas decisiones; no se presume
que este piloto valide planes completos o selección de múltiples objetivos.

La salida normalizada conserva `action`, `primary`, procedencia, hashes de
contexto/petición y revisión. La distribución y confianza, si el proveedor las
ofrece, son evidencia; no se convierten en un umbral de acción arbitrario.
`agent_explanation: null` y `review_status: pending` hacen visible la revisión
pendiente. La explicación posterior y referencias son del agente que las escribe.
Una decisión no ejecuta código, publica cambios ni concede permisos.

El núcleo registra destinos y hashes sin conocer secretos ni tipos de pregunta. Registro explícito
`PROVIDERS` en `scripts/tessera.py`. Cada adaptador implementa `build_request`,
`check_credentials`, `invoke`, `parse_response` y `validate_response`, y ofrece `endpoint()`.
Recibe el mismo contexto; devuelve opción normalizada, modelo, uso y, cuando
existen, probabilidades/confianza. Para añadir otro motor: implementar ese
adaptador real, registrarlo y probarlo con el mismo catálogo/casos. No cambiar
fichas ni reinterpretar decisiones antiguas. No hay adaptadores ficticios de
Claude/Codex ni fallback automático. El usuario exige todas las fichas en cada
consulta: Tessera no hace ranking, top-k, filtros por etiquetas/relevancia ni
partición que descarte candidatos. Si excede el proveedor, falla explícitamente.

## Primer adaptador: TypeSafe Jev

Contrato consultado el 2026-09-27 en la [API oficial](https://docs.typesafe.ai/api):
`POST https://api.typesafe.ai/v1/systemone`, Bearer `TYPESAFE_API_KEY`. Traduce el
contexto a `state`, `model`, `questions.decision` de tipo `choice`. La respuesta
incluye modelo, `answers.decision` y `usage`. Se comprueban opción conocida,
distribución completa/finita, suma aproximada, confianza válida y contadores de uso.
El [SDK oficial](https://docs.typesafe.ai/sdk/python/api/types/responses) especifica
suma aproximada. El cliente admite error menor de 0.02, coherente con la
serialización documentada por Kev, y registra `probability_sum` sin normalizar.
Esta tolerancia numérica no es un umbral de decisión. El piloto detectó y
corrigió un rechazo inicial demasiado estricto de una respuesta con suma 0.99.

No es un agente que abra rutas locales. El adaptador envía el texto preparado.
No genera prosa; [Choice](https://docs.typesafe.ai/primitives/choice) selecciona
una opción declarada. La identidad conjunta acción/objetivo evita combinar dos
respuestas independientes incompatibles.

[Modelo y límites oficiales](https://docs.typesafe.ai/models): `jev-1.13.0`,
entrada textual, 64k tokens por petición y 32k para estado más pregunta mayor.
Choice admite 255 opciones: este adaptador falla al superarlas, sin recortar.
Los bytes se miden localmente; no se presentan como tokens. No hay tokenizer
verificado localmente: los tokens reales se obtienen de la respuesta. Con una
sola pregunta, el límite efectivo de contexto es 32k, no 64k. El catálogo en
disco no tiene ese límite. Este primer adaptador admite hasta 84 fichas por
Choice conjunta (3 acciones por ficha más create/insufficient_evidence).
No es un límite del catálogo neutral. Ante exceso, se comunica el límite sin
recortar, agrupar o elegir fichas por cuenta de Tessera.

El ensayo con todo el código recibió `max_tokens_exceeded` con 132 KB. La
estrategia final envía fichas: unos 22 KB y 5.500 tokens en la primera llamada.
El tamaño no garantiza calidad. Los resultados medidos y fallos de validación
se conservan por separado en el piloto; no se reescriben como aciertos.
La documentación reconoce [limitaciones](https://docs.typesafe.ai/model-jaggedness/jev-1.13);
salida tipada no garantiza una decisión correcta.

## Alternativa: Kev de Jared Palmer

Usuario confirma [jaredpalmer/kev](https://github.com/jaredpalmer/kev). API y
servidor inspeccionados en revisión `9c41005b2180347c3c646dfc9e50c4428483ec6b`:
[`kev/api.py`](https://github.com/jaredpalmer/kev/blob/9c41005b2180347c3c646dfc9e50c4428483ec6b/kev/api.py),
[`kev/serve.py`](https://github.com/jaredpalmer/kev/blob/9c41005b2180347c3c646dfc9e50c4428483ec6b/kev/serve.py).
Mismo POST System One, mismas fichas y preguntas; solo cambian proveedor,
destino, credencial y modelo. Transporte y validación compartidos en
`tessera_systemone.py`; no dependencia del catálogo con Qwen ni con TypeSafe.

`--provider kev` requiere `TESSERA_KEV_ENDPOINT` explícito, terminado en
`/v1/systemone`. Ejemplo para un servidor ya disponible:

```bash
export TESSERA_KEV_ENDPOINT=http://127.0.0.1:8009/v1/systemone
python3 "$SKILL_DIR/scripts/tessera.py" prepare --provider kev \
  --repo "$PROJECT" --task /ruta/local/externa/tarea.json
python3 "$SKILL_DIR/scripts/tessera.py" evaluate --run /ruta/run-kev-nuevo
```

Mantener el mismo destino al evaluar: se compara con el manifiesto antes de
invocar. Solo HTTPS fuera de loopback, sin credenciales en URL; el servidor
remoto requiere `KEV_API_KEY` en el proceso. Loopback admite el servidor local
sin autenticación documentado por upstream. Nunca se reutiliza la clave de
TypeSafe. El helper no descarga pesos ni instala o inicia servidores.

La respuesta usa `kev-latest`: upstream refleja el alias pedido, no prueba el
checkpoint. Registrar además la revisión/configuración del servidor y los
metadatos de `GET /v1/models` antes de comparar resultados reales. No se ha
deducido el checkpoint a partir de ese alias: el piloto verificó el servidor
Kev-0.8B fijado y ejecutó cuatro inferencias reales con contextos idénticos a Jev.
Respondió `insufficient_evidence` en los cuatro casos (0.60–1.18 segundos).
El protocolo funciona; este modelo no ha demostrado utilidad como selector en
el catálogo del piloto. Se conserva como alternativa experimental. No atribuir
la causa al español, tamaño o formato sin una evaluación específica.

Límite adicional que verificar al desplegar: la revisión inspeccionada de
`kev/model.py` permite truncar el estado si no se usa `strict=True`, y
`kev/serve.py` no activa ese parámetro. Para cumplir la política de catálogo
completo, el servidor elegido debe rechazar exceso de contexto sin truncarlo;
no basta con que el cliente envíe todas las fichas. La cifra de contexto del
README indexado y la del código actual difieren; validar la versión desplegada,
no asumir límites por el nombre Kev.

### Instalar Kev en cada equipo

El runtime y los pesos son locales a cada ordenador; no van a dotfiles/GitHub.
Requiere Git, Python 3.11+ para el instalador y [uv](https://docs.astral.sh/uv/getting-started/installation/)
por el mecanismo aprobado en ese equipo. uv prepara Python 3.13 y dependencias
aisladas usando el lockfile upstream; no cambia el Python del sistema.
Inspeccionar SO, RAM, GPU/controlador y espacio libre antes de instalar.

```bash
python3 "$SKILL_DIR/scripts/kev-local.py" install
python3 "$SKILL_DIR/scripts/kev-local.py" check
python3 "$SKILL_DIR/scripts/kev-local.py" serve
```

En PowerShell usar `python` y la ruta de la skill. El runtime predeterminado es
`$XDG_DATA_HOME/tessera/kev` (normalmente `~/.local/share/tessera/kev`) en Linux y
`%LOCALAPPDATA%\tessera\kev` en Windows. `--runtime RUTA` permite otro destino.
No copiar `.venv`, caches, pesos, claves o referencias de secretos entre PCs.
La instalación rechaza destinos existentes. Si uv falló después del checkout,
inspeccionar la revisión y parche de ese destino y recuperar únicamente la
dependencia pendiente con `uv sync --locked --no-dev --extra serve --python 3.13`
desde el runtime; después repetir `check`. No borrar para resolver un conflicto.

En Windows, el wheel PyPI del lock es CPU, incluso con GPU NVIDIA. Tras comprobar
GPU/controlador compatibles, ejecutar explícitamente
`python "$SKILL_DIR/scripts/kev-local.py" windows-cuda` para instalar únicamente
PyTorch 2.8.0+cu128 desde su distribución oficial, con URL y SHA256 fijados para
Python 3.13/Windows x86_64. Es una adaptación declarada del entorno, no del
lockfile upstream. `check` debe mostrar `cuda_build: 12.8` y `cuda: true` antes
de afirmar aceleración. Si se repite `uv sync`, reaplicar `windows-cuda` porque
la sincronización restaura el wheel CPU. No cambiar el controlador para hacer
encajar este runtime sin investigar y obtener la autoridad necesaria.
Fuente: [uv y PyTorch](https://docs.astral.sh/uv/guides/integration/pytorch/).

Se fijan upstream `9c41005b2180347c3c646dfc9e50c4428483ec6b` y modelo
`jaredpalmer/kev-0.8b@9a45d25eb2ab761841196625383fa1dff0e56c1e`.
El parche [kev-strict-context.patch](kev-strict-context.patch) activa rechazo
explícito; prueba real: HTTP 422 para 70.005 tokens de estado, límite 65.536.
El launcher verifica revisión, hash del servidor y ausencia de otro código
modificado. CUDA usa bf16 si el hardware lo admite, de lo contrario fp32.
Sin CUDA, CPU requiere `--allow-cpu`; su latencia debe medirse en el equipo.
Apple Silicon necesita adaptación/verificación específica, no se supone válida.
Los umbrales de 4 GiB libres en bf16 y 6 GiB en fp32 son preflight, no garantizan que
cualquier catálogo quepa. No instala drivers ni reduce fichas por falta de memoria.

El servidor escucha solo en `127.0.0.1:8009`, bajo demanda, sin autostart.
El primer arranque descarga pesos desde Hugging Face; detener con Ctrl+C libera
la GPU. `GET /v1/models` debe mostrar checkpoint, dispositivo y precisión
esperados. El piloto verificó Linux/CUDA; la inferencia en Windows y CPU está
pendiente en el PC del trabajo. No confundir tests portables con esa prueba.

## Criterios de contexto y preguntas

Fuentes oficiales consultadas el 2026-09-27; las recetas con Jev 1.12 no son
resultados medidos de este piloto con Jev 1.13.0.

- [Guía de construcción](https://docs.typesafe.ai/concepts/how-to-build-with-system-one):
  contexto relevante y estructurado, preguntas concretas, lógica determinista
  fuera del modelo. Mantener campos comparables entre fichas y criterios que
  distingan lo admitido de lo no admitido. Una consulta no decide toda la
  arquitectura ni reemplaza inspección y pruebas del agente.
- [Choice](https://docs.typesafe.ai/primitives/choice): incluir todas las opciones
  cuando caben y una salida cuando ninguna encaja. La opción mejor situada es
  relativa a las demás; no demuestra que cumpla la tarea.
- [Skill suggestion](https://docs.typesafe.ai/cookbooks/skill_suggestion): ejemplo
  de 182 skills con comparación general y revisión posterior más detallada.
  Es referencia de investigación, no la política adoptada: el usuario exige
  enviar todas las fichas al motor. Sus tres candidatos y umbrales no se copian.
- [Limitaciones 1.13](https://docs.typesafe.ai/model-jaggedness/jev-1.13): evitar
  ruido, indirección, instrucciones contradictorias y razonamiento encadenado.
  Tratar el catálogo como datos, probar casos ambiguos, ninguno válido e
  instrucciones maliciosas; una advertencia textual no inmuniza al modelo.
- [Confianza](https://docs.typesafe.ai/confidence): medir en casos propios antes
  de automatizar. `confidence` resume la distribución; no equivale a la
  probabilidad de que la implementación funcione. No copiar umbrales de demos.
- [Modelos](https://docs.typesafe.ai/models): inglés es el idioma con mejor
  rendimiento declarado. El piloto conserva requisitos/fichas en español;
  una comparación bilingüe es evaluación pendiente, no una garantía asumida.

## Ejecución reproducible

Resolver `SKILL_DIR` a la carpeta de esta skill y `PROJECT` al checkout del
proyecto, tanto en Claude como en Codex. Ejemplo Bash:

```bash
python3 "$SKILL_DIR/scripts/tessera.py" status --repo "$PROJECT"
# Resolver next_action con el flujo lifecycle.md antes de preparar.
python3 "$SKILL_DIR/scripts/tessera.py" changes --repo "$PROJECT"
python3 "$SKILL_DIR/scripts/tessera.py" prepare \
  --repo "$PROJECT" --task /ruta/local/externa/tarea.json --provider typesafe --require-ready
```

Tras `locate`, el agente crea/actualiza el catálogo en la ruta devuelta, con
carpeta privada y archivo 0600 en POSIX. `prepare` usa ese catálogo y elige una
carpeta nueva bajo `runs/`; devuelve su ruta `run` para `evaluate`. `--catalog`
y `--output` permiten rutas externas explícitas. Los padres que crea el helper
tienen modo 0700. En POSIX, `prepare` exige que catálogo y tarea sean privados
por sus permisos o los de una carpeta antecesora; no cambia permisos existentes.
Windows hereda ACL del almacenamiento privado del usuario.

`prepare` no llama a red. Crea un directorio nuevo (0700 y archivos 0600 en POSIX;
en Windows se heredan las ACL del directorio privado elegido) con `context.json`,
`derived.json`, `request.json` y `manifest.json`. Revisar el contenido que se
enviará, los hashes, proveedor/destino y tamaño. La tarea no debe incluir la
respuesta esperada de una evaluación.

Con autorización vigente para ese envío y una credencial disponible únicamente
para ese proceso mediante el mecanismo de secretos del proyecto:

```bash
python3 "$SKILL_DIR/scripts/tessera.py" evaluate --run /ruta/run-nuevo
```

Se reserva `attempt.json` antes del POST: máximo un intento por run. Sin clave,
no hay intento. HTTP 401/422/429/529, timeout o redirección fallan explícitamente.
Un error de transporte deja resultado desconocido; no reintentar automáticamente.
Revisar la causa/consumo y preparar otro run si se decide reintentar.
No se imprimen credenciales ni cuerpos de error HTTP.

Una respuesta real queda en `response.json`; solo si valida se escribe
`decision.json`. El cuerpo original se conserva antes de parsear, con hash en
la decisión. `failure.json` registra fase y error sin credenciales ni cuerpo de
error HTTP. Un error HTTP conserva su cuerpo en `http-error.bin`, privado y sin
imprimir; inspeccionarlo con cuidado porque el proveedor puede reflejar datos.
Se comprueban destinos antes de invocar; no se sustituyen archivos
existentes. Conservar la respuesta
original y registrar explicación, desacuerdo, resultado y pruebas en un archivo
separado del historial local externo. Verificar de nuevo las fuentes antes de
implementar una decisión antigua. No versionar automáticamente catálogos,
historiales ni runs; contienen conocimiento y contexto del proyecto.
