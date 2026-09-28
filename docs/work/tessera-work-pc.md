# Prompt para actualizar el PC del trabajo

Usar después de publicar y verificar el commit de esta entrega en
`git@github.com:jesus-molano/dotfiles.git`. El mensaje de entrega indicará el OID
y la rama publicados. El PC Windows ya dispone de Kev y el usuario ha comunicado
una prueba real correcta. Este documento prepara su actualización, no acredita
por sí solo un push ni sustituye la comprobación del equipo receptor.

Copiar este prompt y añadir el OID y la rama del mensaje de publicación:

```text
Estamos en mi ordenador del trabajo, distinto del equipo donde se preparó
Tessera. Usaremos Jev como motor habitual; Kev queda como alternativa local.
Actualiza mi checkout local de jesus-molano/dotfiles a la revisión
publicada indicada junto a este prompt y despliega la configuración compartida
de IA. Kev ya está instalado y probado aquí: conserva su runtime, checkpoint,
dependencias y drivers. Completa las comprobaciones necesarias y registra lo
pendiente; no te limites a darme instrucciones.

Primero lee AGENTS.md, docs/ai.md, docs/work/tessera-jev.md,
docs/work/tessera-windows-validation.md y
ai/skills/tessera/references/contract.md del checkout. Comprueba SO, estado Git,
remoto, rama y revisión publicada. Comprueba que los fixes Windows que publicamos
estén incluidos: parche Kev LF/CRLF, fixture CRLF y descarga HF sin symlinks.
Conserva mis cambios locales; actualiza por
fast-forward cuando sea posible. No hagas reset, borres ni sobreescribas cambios
para resolver divergencias. No supongas rutas, GPU, RAM, credenciales ni clientes
instalados iguales a los del ordenador de casa.

Tessera es tooling personal con un catálogo local por proyecto de componentes
y utilidades. Usa tessera.py locate --repo PROJECT para resolver su almacén
externo en LOCALAPPDATA/XDG. No crees .tessera ni cambies .gitignore en repos
del trabajo, y no copies sus fichas, historial o evidencia a dotfiles/GitHub
personal. Dotfiles distribuye las herramientas, nunca información de empresa.
Si el catálogo piloto anterior ya existe en otra ruta local externa, conserva
su copia previa, revisa sus referencias contra el checkout y cópialo al namespace
devuelto por locate. No pierdas las fichas ni borres el original. Conserva los
runs históricos; los antiguos sin repo_path necesitan un prepare nuevo antes
de una evaluación futura, no se deben modificar para reutilizarlos.
Antes de decidir, ejecuta changes: inspecciona cambios de compañeros presentes
en el checkout, actualiza las fichas afectadas, incorpora piezas nuevas y
reconcilia bajas/renombrados. Conserva una copia previa local; actualiza la
revisión del catálogo después de inspeccionar código y usos fuera de tests. No hace
pull ni consulta GitHub automáticamente. El código debe estar actualizado en
este checkout; los compañeros no necesitan Tessera.
Usa ahora status como punto de entrada: distingue inicialización, actualización,
revisión completa y listo. Sigue references/lifecycle.md de la skill para
init/scan, revisar los archivos incluidos por tandas (tests excluidos sin abrirlos) y finalize. Un catálogo previo
de dos fichas no acredita cobertura completa. Usa prepare --require-ready en
las tareas normales; no cambies fechas/revisiones para saltarte la revisión.
Envía TODAS las fichas al motor elegido: nombres, etiquetas, contratos,
restricciones y referencias, sin ranking previo ni top-k. Los archivos de código
completos quedan como evidencia local. Jev, Kev y futuros motores son adaptadores
intercambiables; no cambies de proveedor en silencio. El agente verifica la
decisión, implementa y actualiza el catálogo. Memoria, ODD, workflow y dirección
visual mantienen sus responsabilidades. No recuperes Atlas como dependencia.

Usa el despliegue existente, no uno nuevo. En Windows nativo revisa y ejecuta
scripts/ai-setup.ps1 en modos plan, apply y check; elige Claude o ambos clientes
según los instalados. En Linux usa el checkout canónico main, just ai-plan,
just ai-sync y just ai-check; si cambia la composición del host, aplica antes
el preflight y flujo de docs/ai.md. No uses Stow desde un worktree secundario.
Conserva modelos, esfuerzo, memoria, cuentas, plugins y preferencias locales.
Abre una sesión nueva de los clientes disponibles para comprobar la skill
tessera y su enlace desde engineering-flow.

En Windows usa python con PYTHONDONTWRITEBYTECODE=1. Ejecuta las regresiones
scripts/tests/test_tessera.py, test_tessera_lifecycle.py, test_kev_local.py y test_ai_sync.py por unittest
discover. Comprueba que el despliegue excluye __pycache__, .pyc y .pyo. No borres
copias ajenas si el sincronizador detecta un conflicto; inspecciónalo y conserva
su respaldo antes de resolverlo.

Localiza el runtime Kev ya instalado y ejecuta el check del launcher versionado
ai/skills/tessera/scripts/kev-local.py. No repitas install ni windows-cuda sobre
un runtime correcto. No descargues otro modelo ni cambies drivers o versiones
para esta actualización. Conserva el modo bajo demanda y la configuración local.

Verifica GET http://127.0.0.1:8009/v1/models: checkpoint fijado, dispositivo y
precisión si el servidor está disponible o se arranca para verificarlo. La prueba
Windows ya comunicada verificó CUDA/bfloat16, rechazo 422 de 70.002 tokens frente
al límite 65.536, una decisión con las mismas dos fichas que Jev
(insufficient_evidence, 2,27 s) y 19/19 pruebas de las utilidades del proyecto.
Conserva esa evidencia local. Estos cambios de almacenamiento/sincronización no
requieren repetir inferencia costosa ni llamadas a Jev; si detectas una regresión,
prueba el caso afectado con todas las fichas y registra el resultado por separado.
No copies las fichas ni sus respuestas al repo de dotfiles.
Configura TESSERA_KEV_ENDPOINT para el proceso como
http://127.0.0.1:8009/v1/systemone. No requiere la clave TypeSafe para Kev local.
Para Jev usa solo el mecanismo local aprobado de secretos; no muestres ni
copies claves. No instales un servicio de arranque automático.

Resultados previos: Linux/CUDA en casa ejecutó cuatro casos con Kev-0.8B, pero
los cuatro fueron insufficient_evidence; Jev distinguió las cuatro estrategias,
una con ambigüedad. Kev es experimental, no equivalente en calidad por compartir
API. No ajustes respuestas ni filtres fichas para aparentar un resultado mejor.

Termina informando OID instalado, clientes y skills desplegados, ruta del runtime,
modelo/dispositivo, pruebas reales y resultados, instrucciones de arranque y
parada, respaldo para revertir configuración y cualquier bloqueo concreto.
No publiques más cambios como parte de esta actualización.
```
