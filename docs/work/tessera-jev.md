# Tessera y motores de decisión: piloto

## En curso: inicialización y estado por proyecto

Petición del usuario: saber cuándo inicializar, continuar una catalogación,
actualizar cambios o revisar el proyecto completo. Base `755588b`.

- Inventario de todo el árbol Git, sin selección por tarea o extensión. Los
  secretos, enlaces y submódulos se identifican por metadata y no se leen.
- `status` solo lee; `init`/`scan` generan inventario externo reanudable.
  El agente clasifica por tandas, escribe fichas y registra razones de exclusión.
  `finalize` valida cobertura y contratos antes de declarar listo el catálogo.
- Estados: sin inicializar, inicializando, actualización pendiente, revisión
  completa necesaria, listo y bloqueado. Cobertura y vigencia se distinguen.
- Los catálogos previos se conservan; no adquieren cobertura completa por tener
  una revisión Git actual. Sin consumidores encontrados se registra una razón
  explícita, sin inventar usos.
- Reutilización: helper Git, rutas externas, permisos y captura de Tessera;
  patrón de lock O_EXCL, backup y reemplazo atómico de sync-ai/sync-codex-config.
  Scout no encontró un inventario integral ya implementado.
- Mantener todas las fichas en cada petición al motor. No nuevas llamadas a
  Jev/Kev, no cambios de modelos ni servicio automático.

Aceptación: transiciones probadas sobre repos Git reales temporales; tandas
reanudables; altas/bajas/renombrados, cambios de consumidores, ramas y baseline
ausente; no escritura en repo ni lectura de secretos; respaldo/concurrencia;
rechazo de preparación cuando se exige cobertura completa y no está lista.
Implementado el flujo y la guía `references/lifecycle.md`. Pruebas nuevas sobre
repos temporales cubren transiciones, tandas/locks obsoletos, privacidad,
rollback de escritura interrumpida y cambios del catálogo antes de red.
El status real de Expenses detecta `needs_full_review`: su catálogo de 14 fichas
no acredita revisión del árbol completo (266 archivos, uno protegido). No se
leyeron sus fuentes ni se amplió su catálogo para esta verificación de estado.
Revisión independiente cerrada en dos pasadas: corregidas la política de rutas
privadas, lectura consistente de inventario/hash, recaptura de cobertura durante
prepare y compatibilidad Git SHA-256. Última pasada sin hallazgos accionables.
Verificación: 59 pruebas Tessera correctas; suite completa de 195 (194 correctas,
una omitida), quick_validate, render y 18 skills/cinco roles válidos. No hubo
peticiones a Jev/Kev. La catalogación semántica completa de Expenses sigue
pendiente: esta entrega implementa y prueba el flujo, no inventa fichas.

## Objetivo y decisiones del usuario

Tessera es el catálogo local de componentes/utilidades por proyecto.
Se amplía durante el trabajo y sustituye la responsabilidad de catálogo de
Atlas. Memoria, ODD, continuidad y diseño mantienen sus propietarios.
Jev (TypeSafe) y Kev (Jared Palmer, confirmado por el usuario) son proveedores
intercambiables. Otros motores requieren un adaptador verificado, no rehacer
las fichas ni simular una API futura.

El usuario exige enviar todas las fichas al motor: Tessera no clasifica, filtra
por etiquetas/relevancia ni hace top-k. El proveedor decide reuse, modify,
wrap, create o insufficient_evidence. El agente verifica la decisión contra
código y consumidores antes de implementar. Se envían fichas completas con
nombres, etiquetas, contratos, restricciones y referencias; los archivos
completos de código, usos, pruebas y estilos permanecen como evidencia local.

Corrección posterior del usuario: al ser tooling personal, no introducir sus
catálogos ni historial en repos del trabajo ni en GitHub/dotfiles personales.
El valor por defecto pasa a almacenamiento externo bajo XDG/LOCALAPPDATA,
separado por proyecto. Compartir en un repo requiere una excepción explícita.
También exige detectar cambios de compañeros y actualizar las fichas al usar
Tessera. `locate` resuelve el almacén; `changes` informa del delta; el agente
inspecciona y actualiza contratos, usos, pruebas, altas, bajas y renombrados.
Esto detecta cambios presentes en el checkout, no consulta remotos en segundo
plano. El proveedor sigue recibiendo todas las fichas una vez actualizadas.

Esta corrección sustituye las recomendaciones previas de crear
`.tessera/catalog.json` y versionarlo automáticamente. El piloto personal
ya publicado es evidencia histórica, no información corporativa ni una plantilla
de almacenamiento para el trabajo. No se borró ni se migró ningún repo ajeno.

## Estado de trabajo

Base dotfiles: `a7e0481da6a8fb66409e3501d0a535f33fe1d13b`, worktree inicialmente
limpio. No desplegar desde este worktree ni publicar sin autorización del
remoto y OID exactos. La app piloto no se modifica. No borrar checkout/datos
Atlas. Los planes del ZIP aportado son antecedentes, no permisos adicionales.
El nombre ODD no se ha localizado en los archivos; no se redefine.

## Evidencia y reutilización

- Leídos `docs/ai.md`, `docs/work/dual-ai.md` y los dos Markdown del ZIP
  `planes-tessera-jev-claude-codex.zip`.
- Scout: Atlas `packages/mcp/src/core-reuse-decision.ts` depende de su grafo e
  identidades; no sirve de núcleo neutral. Se crea un helper Python estándar
  pequeño, siguiendo los scripts existentes de dotfiles.
- Piloto: `/home/jesus-molano/dev/Expenses-Log-App`, revisión limpia
  `95c2f2465e355cffeee7f363d116ec160ff852eb`.
- 14 fichas: todo `src/components/ui` y `src/shared/ui.ts`; cobertura declarada,
  no toda la aplicación. 29 archivos de evidencia local; 44 opciones.
- La fuente de contratos y límites es oficial:
  [TypeSafe API](https://docs.typesafe.ai/api),
  [guía de construcción](https://docs.typesafe.ai/concepts/how-to-build-with-system-one),
  [Choice](https://docs.typesafe.ai/primitives/choice),
  [limitaciones 1.13](https://docs.typesafe.ai/model-jaggedness/jev-1.13),
  [ejemplo de skills](https://docs.typesafe.ai/cookbooks/skill_suggestion).
- Investigación y contrato operativo en
  `ai/skills/tessera/references/contract.md`. Las recetas de ranking por etapas
  son antecedentes, no la política adoptada. No copiar umbrales de demos.

## Implementación

- `ai/skills/tessera/scripts/tessera.py`: fichas curadas, evidencia local,
  contexto neutral compacto y decisiones separadas. IDs estables y hashes.
- `tessera_systemone.py`: protocolo/transporte compartido; recibe endpoint y
  credencial del adaptador. No decide qué fichas enviar.
- `tessera_typesafe.py`: Jev `jev-1.13.0`, destino oficial fijo.
- `tessera_kev.py`: Kev, destino explícito por `TESSERA_KEV_ENDPOINT`, credencial
  propia `KEV_API_KEY`, alias `kev-latest`. Nunca recibe la clave TypeSafe.
- Preparación offline, permisos privados, revisión limpia y curación vigente,
  integridad antes del envío, un intento por run, respuesta bruta conservada,
  errores explícitos, sin fallback ni reintentos automáticos.
- `engineering-flow` consulta Tessera ante decisiones de implementación. La
  skill mantiene separadas dirección visual, memoria y flujo existente.
- Almacén local por hash del git-common-dir real: worktrees del mismo checkout
  comparten catálogo, clones independientes no. No emplea URLs ni credenciales
  para identificar el proyecto. No hay sincronización de datos entre PCs.
- `changes` detecta cambios de fuente/consumidores/tests, altas y bajas, archivos
  fuera del catálogo y línea base ausente. El agente conserva copia previa en
  `history`, actualiza significado y después marca la revisión inspeccionada.
- `evaluate` verifica de nuevo la evidencia local antes de hacer una petición.
  Los runs antiguos sin ruta de checkout necesitan preparación nueva.

## Resultados Jev

El usuario completó registro y guardó la clave en 1Password. Se utiliza solo
mediante `with-secrets` para el proceso; no se leyó `.env`, no se mostró la clave
ni se versionó su referencia. GET de modelos autenticado: correcto.

10 POST de piloto: dos intentos iniciales HTTP 400, cuatro con fuentes completas
y CSS por referencia, cuatro con fichas compactas. El segundo HTTP 400 conservó
`max_tokens_exceeded`; el primero no conservó cuerpo. Los runs privados quedan
ignorados. No presentar preparación offline como una ejecución de modelo.

La estrategia final de fichas usa 21.7–21.9 KB y 5.500–5.536 tokens por tarea.
El ensayo anterior con fuentes y CSS por referencia usó unos 24.500 tokens.
No se elimina ninguna de las 14 fichas ni de las 44 opciones.

| Caso | Elección compacta | Confianza | Revisión |
|---|---|---|---|
| action-button | reuse:button | 0.44 | Fuente respalda reuse; motor ambiguo entre reuse/wrap/modify |
| select-order | modify:select-menu | 0.98 | Orden interno obligatorio; necesita opción nueva |
| pending-action | wrap:button | 0.96 | Componer pending sin cambiar Button |
| signature-pad | create | 0.98 | Ninguna ficha del ámbito implementa dibujo |

La primera respuesta compacta sumó probabilidades 0.99. El validador original
la rechazó con tolerancia 1e-6. La investigación del SDK confirmó suma
aproximada; Kev documenta tolerancia de serialización 0.02. Se corrigió el
cliente y revalidó el cuerpo original offline, sin normalización ni llamada
nueva. Se conserva `failure.json` y un `revalidation.json` separado.

`measurements.json` registra bytes/tokens/latencia/hashes y la incidencia;
`decisions.json` contiene revisión atribuida al agente. `expectations.json`
no se envía al motor. Son cuatro escenarios sintéticos sobre código real, una
muestra pequeña; no demuestran precisión general, estabilidad ni calidad de
cambios implementados. La app sigue intacta.

## Kev local verificado

El usuario solicita preparar Kev en este equipo. Scout no encontró instalación
ni proceso previo. GPU comprobada: RTX 3060 Ti, 8 GB, aproximadamente 7 GB libres;
RAM 32 GB. Modelo inicial elegido: Kev-0.8B, con margen para el escritorio.
No asumir calidad equivalente a Jev ni a Kev-4B/9B/27B.

Runtime aislado bajo `~/.local/share/tessera/kev`, Python 3.13 gestionado por uv,
sin cambiar paquetes del sistema, controladores ni habilitar servicios.
Upstream inspeccionado: `9c41005b2180347c3c646dfc9e50c4428483ec6b`.
El servidor llama a encode sin `strict=True` y puede truncar contexto; la
instalación local aplica el parche mínimo versionado y comprueba su hash.
Prueba real: 70.005 tokens de estado producen HTTP 422, límite 65.536, sin inferir
sobre una entrada recortada. GET de modelos verificó checkpoint, CUDA y bf16.
Se fijó `jaredpalmer/kev-0.8b@9a45d25eb2ab761841196625383fa1dff0e56c1e`.

Las cuatro consultas reales recibieron contextos idénticos byte a byte a los
de Jev, con todas las fichas. Las cuatro eligieron `insufficient_evidence`,
confianza 0.1434–0.1767, latencia 0.60–1.18 s, 4.117–4.150 tokens de entrada.
Snapshot total de GPU tras las llamadas: 3.127 MiB usados, incluido escritorio;
no es pico ni consumo exclusivo del modelo. El contrato funciona; no se ha
demostrado utilidad de este checkpoint como selector para esta tarea.

Diagnóstico solicitado por el usuario: un control simple en inglés eligió
correctamente billing. Cuatro consultas con todas las fichas y solo selección
del componente (15 opciones) eligieron button/none/none/none. Simplificar ayudó
parcialmente, pero no resolvió modificar/envolver. No se aisló efecto del idioma
ni se demuestra una causa única. `kev-measurements.json` conserva resultados;
las respuestas brutas siguen privadas. Diez POST locales: uno de límite, cuatro
del protocolo principal y cinco de diagnóstico. No cambió el protocolo principal.

Decisión final del usuario: Jev como motor habitual, mantener Kev-0.8B en casa,
evaluar el mejor Kev compatible con el hardware del PC del trabajo. No descargar
ni afinar otros modelos aquí. Kev-4B declara unos 9 GB VRAM para serving, frente
a los 8 GB de este PC. La conversión GGUF encontrada usa otro runtime y contexto
2.048, insuficiente tal cual para este piloto; no se incorpora.

`kev-local.py` instala en destino nuevo, verifica fuente/parche y arranca bajo
demanda. Se probó también instalación Linux nueva en ruta temporal con espacios.
Windows tiene paso explícito `windows-cuda` porque el wheel PyPI inicial es CPU;
el wheel oficial CUDA está fijado por URL/hash y no cambia el lock upstream.
La inferencia Windows no se verificó desde este host; el usuario aporta después
el resultado indicado abajo. CPU sigue sin inferencia verificada. No se habilita autostart.
El servidor del piloto quedó detenido y el puerto 8009 libre al terminar.
El launcher local bajo `~/.local/share/tessera/serve-kev-local.sh` sigue
disponible para el runtime de casa; la versión portable gestionada pertenece
a la skill y se despliega mediante el flujo común.

### Resultado comunicado desde el PC Windows

El usuario comunica una prueba real: `/v1/models` confirma checkpoint fijado,
CUDA y bfloat16; 70.002 tokens de estado producen HTTP 422 frente al límite
65.536, sin truncado. Con las mismas dos fichas que Jev, Kev responde
`insufficient_evidence` en 2,27 s. Las dos utilidades del proyecto pasan 19/19
pruebas. Es evidencia aportada desde ese equipo, no una ejecución en este host.
Confirma funcionamiento técnico; no establece calidad suficiente del selector.
Jev permanece como motor habitual y Kev como alternativa experimental.

El PC del trabajo ya tiene runtime. La siguiente actualización conserva su
checkpoint, drivers y dependencias; no repite la instalación ni amplía el modelo.
Los arreglos de portabilidad comunicados allí cubren LF/CRLF del parche Kev,
fixture CRLF de Tessera y descargas Hugging Face sin symlinks en Windows.
El commit `53c72c15a42231275cf3ae351a841a70851d217a` publicado desde ese equipo
se integra completo con las correcciones locales. Su informe reproducible está
en `docs/work/tessera-windows-validation.md`; este host verifica la integración
con las regresiones Python, no repite la inferencia Windows.

## Verificación y continuación

- App: tres archivos, cinco pruebas superadas (`SelectMenu`, estilos y parser).
  Sin cambios UI; no se afirma prueba en navegador.
- Dos pasadas independientes del revisor: hallazgos de integridad, permisos,
  curación, concurrencia, respuestas y taxonomía corregidos y probados. Cambios
  posteriores de contexto compacto y Kev no han tenido tercera pasada.
- 29 pruebas enfocadas cubren núcleo, adaptadores, aislamiento de credenciales,
  igualdad de fichas entre motores y redondeo. Otras seis verifican el launcher
  nuevo, conservación del runtime, integridad y rutas de hardware.
- La revisión independiente del launcher detectó ruta CUDA Windows, código
  no versionado en raíz y margen fp32; corregidos y cubiertos por esas pruebas.
- Auditoría del host: tres fallos previos (checksums base de Hyprland,
  mnt-backups.mount y restic-backup.service). Fuera del alcance; no modificados.
- Validación final: 163 pruebas Python superadas (una omitida), `just lint`
  sin fallos/avisos, `just check` correcto con siete avisos de plugins Noctalia
  ausentes en HOME hermético; 18 skills y cinco roles válidos,
  `render-ai.py --check`, quick_validate, Bash/ShellCheck y diff correctos.
- El piloto `0bdff86` fue publicado con autorización y desplegado desde main
  en este equipo. La entrega posterior incorpora almacenamiento externo,
  comprobación de cambios de compañeros y exclusión de caché Python en las
  exportaciones de skills. El prompt actualizado está en
  `docs/work/tessera-work-pc.md`.
- No se desplegará un catálogo dentro de la app: la corrección del usuario exige
  almacén local externo. Evaluación con ambos clientes y recuperación de
  visual-direction siguen siendo fases posteriores; esta entrega no las ejecuta.

Verificación de la actualización local del 28 de septiembre: 40 pruebas Tessera
y suite completa de 175 pruebas (174 correctas, una omitida), `just lint` sin
fallos ni avisos, `just check` correcto con los siete avisos Noctalia del HOME
hermético, render y validación de 18 skills/cinco roles correctos. La revisión
independiente detectó y cerró cambios locales fuera de ámbito, revalidación de
la ubicación de runs trasladados y privacidad POSIX de las entradas. La última
pasada no encontró más problemas; el filtro de caché conserva backups completos.
Estas pruebas no hacen llamadas nuevas a Jev/Kev ni acreditan ejecución Windows.
Tras integrar el commit Windows, la suite conjunta pasa 176 pruebas en este
host (175 correctas, una omitida), incluida la regresión real Git de parches
LF/CRLF. Las nuevas comprobaciones de almacenamiento y exportación deben
ejecutarse también en el PC receptor mediante el prompt de actualización.
