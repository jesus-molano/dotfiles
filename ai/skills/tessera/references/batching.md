# Decisiones completas por lotes

La unidad de cobertura es una decisión completa, no una petición HTTP. Todas
las fichas llegan al proveedor en la primera ronda, una vez cada una, con sus
contratos, restricciones y referencias completas. Tests siguen fuera de todo
el flujo. No hay selección previa por similitud, categoría, ranking o top-k.

`prepare --require-ready` mantiene el protocolo directo si cabe. Si no, guarda
en `request.json` un plan `exhaustive-batches-v1`, no un cuerpo HTTP único.
El plan ordena por ID estable y agrupa sin separar las tres estrategias de una
ficha. Cada petición admite hasta 255 opciones y 24.000 bytes serializados.
Ese presupuesto conservador de bytes no es un recuento de tokens ni sustituye
el límite del servidor. `token_count` sigue siendo null antes de una llamada.
No recortar contratos ni reintentar tras un rechazo de contexto.

Cada lote permite elegir una pareja acción/ficha, `create` (ninguna ficha de
ESE lote satisface la tarea) o `insufficient_evidence`. El coordinador espera
a que todos terminen correctamente. Luego el mismo proveedor compara las
propuestas seleccionadas, conservando su acción y contrato completos; incluye
crear y abstenerse en cada comparación. Si hace falta, repite rondas acotadas.
No suma ni compara probabilidades de preguntas distintas. Las propuestas
descartadas por el proveedor permanecen trazadas en el historial.

Una incertidumbre previa impide concluir creación global: se acepta una
propuesta concreta respaldada o abstención. Si el proveedor devuelve `create`
al final pese a esa incertidumbre, el run falla sin inventar otra respuesta.
La confianza final corresponde solo a esa comparación final, no al catálogo
entero ni a una confianza agregada. El agente siempre verifica la elección.

Antes de red se comprueba que cada ficha cabe íntegra y que dos finalistas
pueden compararse juntos. El plan incluye máximo de llamadas, hasta 128,
calculado para que incluso reducciones de dos en dos tengan espacio suficiente.
Un plan que exceda esos límites falla explícitamente. No reserva automáticamente
otro proveedor ni modifica el catálogo para encajar.

## Ejecución y trazabilidad

`evaluate` verifica el plan reconstruyéndolo desde el contexto, los hashes,
la revisión y la evidencia local. Mantiene proveedor y destino durante todo el
run. Antes de cada llamada y al cerrar comprueba que checkout y catálogo ready
siguen vigentes. Cada llamada se guarda en `calls/0000/`, etc., con petición,
reserva previa `attempt.json`, respuesta original y resultado validado con hashes.
En Windows usa rutas Win32 extendidas para los artefactos anidados; no requiere
cambiar la política de rutas largas del equipo. Rechaza un directorio `calls`
preexistente, incluidos enlaces, antes de enviar peticiones.
No se escribe `decision.json` global hasta acabar todas las rondas.

El resultado global conserva IDs evaluados, resultados de todas las llamadas,
consumo total real, respuesta final y procedencia. Un HTTP fallido, timeout,
respuesta inválida o cambio del checkout detiene la ejecución. El historial
parcial se conserva; el run no se puede reanudar ni repetir automáticamente.
Resolver la causa y preparar otro run es una operación explícita.

El manifiesto muestra lotes iniciales y máximo de llamadas: revisarlos antes
de enviar material. `prepare` nunca llama al proveedor. Los runs directos
compatibles conservan su protocolo; un plan antiguo incompatible se rechaza,
no se reescribe. Kev comparte el planificador pero conserva su adaptador y
credencial propios; su calidad no se presume equivalente a Jev.

## Calidad y límites de la evaluación

Todas las fichas se consideran antes de elegir propuestas, pero una ganadora
local puede depender de qué otras fichas compitan en su lote. El orden por ID
da reproducibilidad, no demuestra invariancia semántica. Al evaluar calidad,
usar casos de reutilizar, modificar, envolver, crear y abstenerse; variar el
agrupamiento y medir exactitud, abstenciones, tokens y latencia. No presentar
pruebas con proveedor simulado como evidencia de calidad del modelo.

Referencias de diseño: [selección de skills de TypeSafe](https://docs.typesafe.ai/cookbooks/skill_suggestion)
propone bloques y comparación posterior para catálogos mayores;
[Choice](https://docs.typesafe.ai/primitives/choice) limita cada pregunta a 255
opciones. Son antecedentes del diseño, no resultados de Tessera.
