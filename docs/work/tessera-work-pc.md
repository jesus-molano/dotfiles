# Prompt para actualizar el PC del trabajo

Usar después de publicar y verificar el commit de esta entrega en
`git@github.com:jesus-molano/dotfiles.git`. El mensaje de entrega indicará el OID
y la rama publicados. La instalación actual de casa no existe en el otro PC.
Este documento no acredita un push ni una prueba en Windows.

Copiar este prompt y añadir el OID y la rama del mensaje de publicación:

```text
Estamos en mi ordenador del trabajo, distinto del equipo donde se preparó
Tessera. Usaremos Jev como motor habitual; Kev queda como alternativa local.
Actualiza mi checkout local de jesus-molano/dotfiles a la revisión
publicada indicada junto a este prompt, despliega la configuración compartida
de IA e instala Kev localmente en este ordenador. Completa las comprobaciones
reales y registra lo pendiente; no te limites a darme instrucciones.

Primero lee AGENTS.md, docs/ai.md, docs/work/tessera-jev.md y
ai/skills/tessera/references/contract.md del checkout. Comprueba SO, estado Git,
remoto, rama y revisión publicada. Conserva mis cambios locales; actualiza por
fast-forward cuando sea posible. No hagas reset, borres ni sobreescribas cambios
para resolver divergencias. No supongas rutas, GPU, RAM, credenciales ni clientes
instalados iguales a los del ordenador de casa.

Tessera es el catálogo versionado por proyecto de componentes y utilidades.
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

Kev necesita instalación nueva en este PC. Inspecciona hardware, controladores,
RAM y espacio; comprueba Git, Python 3.11+ y uv. Instala las herramientas que
falten por un mecanismo permitido en este equipo, sin eludir políticas ni
modificar drivers automáticamente. Ejecuta el instalador versionado
ai/skills/tessera/scripts/kev-local.py install, después check y serve.
En Windows con NVIDIA compatible, entre install y check ejecuta el subcomando
windows-cuda: el wheel PyPI inicial es CPU; esta opción instala el wheel oficial
CUDA 12.8 fijado por versión y hash. Verifica cuda_build y cuda, no solo el
nombre de la GPU. Esta ruta requiere prueba real aquí, no se probó en casa.
El launcher actual reproduce Kev-0.8B. Mi preferencia para este PC es el mejor
Kev que permita su hardware con margen para el catálogo y mis aplicaciones.
Tras el inventario, consulta las fichas oficiales de los modelos y, si cabe uno
mejor, prepara un checkpoint fijado y una configuración local explícita para
ese modelo, con límites ajustados y pruebas. No cambies el 0.8B del PC de casa
ni presentes el modelo mayor como validado antes de probarlo. Si no cabe, deja
constancia y conserva Jev como motor habitual; no recortes el catálogo.
En Windows usa python; en Linux python3. El runtime se crea fuera de dotfiles,
por usuario, con Python 3.13 y versiones fijadas. No copies .venv ni claves desde
casa. Si no hay CUDA, evalúa el modo CPU explícito --allow-cpu y mide su latencia;
no presentes la detección de hardware como prueba de inferencia. Si la versión
fijada no funciona en este SO, diagnostica antes de sustituir dependencias y
documenta cualquier cambio necesario.

Verifica GET http://127.0.0.1:8009/v1/models: checkpoint fijado, dispositivo y
precisión. Ejecuta una decisión real mediante Tessera, con todas las fichas de
un proyecto disponible y su checkout limpio. El piloto Expenses-Log-App solo
sirve si ese repositorio/revisión está aquí; no inventes sus rutas ni crees un
catálogo que pretenda cubrir código ausente. Si no hay proyecto, comprueba la
API con un caso sintético y deja explícita la prueba de integración pendiente.
Comprueba que un estado que excede el límite devuelve 422, sin truncado.
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
No publiques más cambios sin la autorización exigida por AGENTS.md.
```
