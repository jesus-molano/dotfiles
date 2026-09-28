# Estado e inicialización completa

Ejecutar `tessera.py status --repo PROJECT` antes de decidir una implementación.
Es local, sin red ni escrituras. Devuelve estado, `next_action`, razones, revisión,
rutas, hash del inventario, recuentos y archivos pendientes/protegidos/eliminados.

| Estado | Significado | Siguiente paso |
|---|---|---|
| `uninitialized` | Sin inventario ni catálogo | `init` y catalogación inicial |
| `initializing` | Inventario creado; revisión/finalización incompleta | Reanudar pendientes |
| `needs_update` | Un catálogo finalizado cambió o cambió su inventario | `scan`, revisar delta y `finalize` |
| `needs_full_review` | Catálogo antiguo sin inventario, política incompatible o baseline no disponible | `init` o `scan --full`, según `next_action` |
| `ready` | Inventario revisado, catálogo validado y ambos vigentes | `prepare --require-ready` |
| `blocked` | Checkout con cambios, inventario ilegible o ubicación inválida | Resolver la causa conservando datos |

`curate_catalog` y `resolve_checkout_changes` son acciones del agente, no comandos.
`ready` acredita cobertura del árbol Git revisado, no calidad de una decisión,
pruebas superadas ni capacidad suficiente del proveedor. Los motores mantienen
sus límites: el adaptador Choice actual admite 84 fichas. Un catálogo mayor
puede estar completo; la petición falla explícitamente, sin recortar fichas.

## Primera pasada y reanudación

1. `init --repo PROJECT` crea `inventory.json` en el namespace externo de
   `locate`. Conserva el catálogo existente y es idempotente. Trabajar sobre un
   checkout limpio; no hacer commits de cambios ajenos, reset ni pull para
   despejar el estado. No editar `.gitignore` del proyecto para instalar Tessera.
2. El inventario incluye **los archivos del árbol Git salvo tests y sus artefactos**, sin filtrar por
   lenguaje, carpeta de UI o relevancia para la tarea entre las implementaciones. Los archivos sin seguimiento
   no ignorados bloquean la captura; los ignorados no forman parte de la cobertura.
   Secretos reconocibles por ruta, enlaces y submódulos aparecen como `protected`:
   no se abre su contenido. Un submódulo se cataloga separadamente como proyecto;
   no afirmar cobertura de su interior ni del destino de un enlace.
   La protección por rutas es conservadora, no detecta cualquier secreto por
   contenido. Respetar además las rutas privadas de las instrucciones del
   proyecto: excluirlas con esa razón sin abrirlas. No asumir que un pendiente
   está libre de secretos ni abrir indiscriminadamente almacenes de credenciales.
3. Inspeccionar todos los pendientes por tandas reanudables. El agente principal
   puede delegar áreas independientes a `reuse-scout`, solo lectura, para obtener
   evidencia. El scout ayuda a descubrir; no filtra candidatos antes de Jev.
   Clasificar cada archivo como `catalogued`, `supporting` o `excluded`, con razón
   concreta. Excluir documentación, dependencias o código generado por su
   naturaleza comprobada, nunca por irrelevancia para la tarea del momento.
4. Crear/ampliar `catalog.json`, con respaldo previo en `history/`. Leer contratos,
   exports y consumidores que no sean tests; agrupar los exports reutilizables de un archivo
   en su ficha. No inventar usos: si no se encuentran, `usages: []` necesita
   `usage_gap` explicando la búsqueda o el uso implícito del framework. Omitir el campo
   `tests`; no buscar ni leer pruebas. Mantener `scope` coherente con todas
   las fuentes catalogadas; puede enumerar archivos concretos de todo el repo.
5. Registrar cada tanda con `review --repo PROJECT --batch EXTERNAL_BATCH.json`.
   Usar `revision` e `inventory_sha256` de un `status` reciente. La tanda no escribe
   fichas ni acredita que el agente las leyó: registra su revisión explícita.
6. Con cero pendientes, ejecutar `finalize --repo PROJECT`. Valida el catálogo,
   su revisión, correspondencia con las fuentes clasificadas y sus evidencias.
   Solo entonces puede aparecer `ready`. Si falla, corregir la causa y reanudar.

Ejemplo de tanda (las revisiones y rutas deben proceder del proyecto real):

```json
{
  "schema": 1,
  "revision": "OID_DE_STATUS",
  "inventory_sha256": "HASH_DE_STATUS",
  "files": [
    {"path": "src/format.ts", "kind": "catalogued", "reason": "Contrato y consumidores revisados"},
    {"path": "README.md", "kind": "excluded", "reason": "Documentación sin implementación reutilizable"}
  ]
}
```

## Exclusión de tests antes de leer

El helper aplica `is_test_path` al nombre, antes de abrir contenido. Omite
carpetas `test`, `tests`, `spec`, `specs`, `__tests__`, `e2e`, `cypress`,
`__fixtures__`, `__mocks__`, `__snapshots__`, `test-results`, `playwright-report`,
`coverage`, `.pytest_cache` y `.nyc_output`; nombres `test_...`, `test-...`,
`*.test.*`, `*.spec.*`, `*_test.*` y equivalentes con guion/punto, además de
`*Test.java`, `*Tests.java`, Kotlin y C#. También omite `conftest.py` y
`vitest`/`jest`/`playwright`/`cypress` con sufijos `.config.*` o `.setup.*`.
No analiza contenido para descubrir
si un archivo es un test. Si el proyecto declara otra convención, identificarla
por su ruta y ampliar el predicado antes de inspeccionar esos archivos.

No aparecen en pendientes, fuentes, consumidores ni evidencia de soporte. No
leerlos manualmente ni delegar su análisis. `ready` acredita únicamente el árbol
incluido por esta política. Los cambios confirmados solo en tests no invalidan
el catálogo; sigue siendo obligatorio trabajar con un checkout limpio.

La política 2 migra inventarios de política 1 con `scan`: guarda copia en
`history`, retira tests por ruta y conserva clasificaciones de los otros archivos
solo si su objeto Git y modo no cambiaron. Requiere finalizar de nuevo, sin
repetir la revisión válida. No usar `scan --full` para esta migración compatible.
Los campos antiguos `tests` se aceptan pero se ignoran sin resolver sus rutas y
se eliminan del contexto del proveedor. Al curar el catálogo, retirarlos con
copia previa. Una referencia test en `source`, `usages` o `supporting_files`
se rechaza; retirarla y revisar el contrato/consumidor real. Conservar los runs
históricos y preparar uno nuevo; nunca reescribir evidencia antigua.

## Tipo de pieza y responsabilidad del agente

El `kind` de una ficha describe su naturaleza; es distinto de la clasificación
del archivo en el inventario. Es texto extensible, no una inferencia del nombre:

- `component`: UI y su contrato de propiedades, eventos, slots o composición.
- `hook` / `composable`: estado, reactividad o ciclo de vida del framework.
- `utility`: operación reutilizable, con entradas, salidas y efectos explícitos.
- `page`: pantalla/ruta; revisar también exports y comportamiento reutilizable.
- `service`: acceso a API, persistencia u otras operaciones compartidas.
- Otros tipos/módulos mixtos: describir todos sus exports relevantes, sin forzar
  categorías incorrectas. Usar `name`, `tags`, contrato y restricciones para
  distinguirlos. Ubicación y nombre son pistas; comprobar código y consumidores.

Una pieza ambigua sigue pendiente. `excluded` necesita una razón verificable,
no "no la necesito ahora". El sistema prueba contabilidad de archivos y vigencia;
la calidad semántica de la clasificación depende de la inspección del agente.

## Mantenimiento

`scan` compara todo el árbol actual y conserva revisiones solo si el objeto Git
y modo del archivo coinciden. Altas, cambios y renombrados requieren revisión;
las bajas se reconcilian con el catálogo. `changes` complementa el informe con
fichas y evidencias afectadas. Revisar dependientes cuando cambie un contrato.
Actualizar `reviewed_revision` después de la inspección, no para quitar un aviso.
Finalizar de nuevo antes de la decisión. Tras implementar y verificar, repetir
la actualización sobre la revisión confirmada.

`scan --full` invalida las clasificaciones anteriores con respaldo y conserva
las fichas. Usarlo ante política incompatible, baseline perdido o revisión total
solicitada; no en cada tarea ni por el mero paso del tiempo. Cambiar de rama o
worktree compara el árbol correspondiente; no exige repetir lo que sigue igual.

Las escrituras usan `inventory.lock`, respaldo privado y reemplazo atómico.
Una tanda obsoleta se rechaza. Si queda un lock tras una interrupción, comprobar
que no haya otro proceso y aplicar las reglas del proyecto antes de retirarlo;
no borrarlo automáticamente. No hay watcher, fetch, pull ni llamada al proveedor.

Los flujos manuales antiguos pueden usar `prepare` sin `--require-ready`, pero
el manifiesto dice `project_status: not_checked`; no acreditan cobertura completa.
El workflow normal exige la opción. `evaluate` vuelve a comprobarla antes de red.
