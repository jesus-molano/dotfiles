# Claude y Codex: configuración compartida

La fuente común vive en `ai/`. Codex y Claude conservan cuenta, memoria, historial,
conexiones ajenas y selección de modelo/esfuerzo por equipo. `AGENTS.md` es el
contrato de cada proyecto. Esta configuración afecta a Claude Code (CLI y pestaña
Code de Desktop); no convierte el chat normal ni Cowork en un agente de código.

## Equivalencias verificables

| Capacidad | Fuente | Codex | Claude Code |
|---|---|---|---|
| Reglas comunes | `ai/rules/common.md` | `~/.codex/AGENTS.md` generado | `~/.claude/CLAUDE.md` generado |
| Reglas locales | Proyecto | `AGENTS.md` | `CLAUDE.md` y `AGENTS.md` con `agents-md@builtin` |
| Skills propias | `ai/skills/` | `~/.agents/skills/` | `~/.claude/skills/` |
| Roles | `ai/roles/*.json` | TOML regulares; Luna/Sol | Markdown regulares; Haiku/Opus high |
| Autonomía técnica | Adaptador | `never`, `danger-full-access` | `bypassPermissions` y ajuste de Desktop |
| Modelo principal | Preferencia local | Se conserva modelo/esfuerzo | Predeterminado de suscripción; después se conserva la elección |
| MCP | Fusión por claves | TOML | `.claude.json` del usuario |
| Continuidad | Repositorio | Un documento de tarea | El mismo documento de tarea |
| Escritorio | `host.toml` local | `special:chatgpt` | `special:claude` |

La fuente incluye 17 skills propias y la skill oficial `playwright-cli`.
`tessera` se añade en esta fase; su despliegue y prueba con ambos clientes siguen
pendientes. En Windows se excluye
`cachyos-host-audit`; los cinco roles siguen disponibles para revisar código,
incluido código Linux sin ejecutarlo. Los revisores Claude solo tienen Read,
Glob, Grep, WebFetch y WebSearch. El principal ejecuta las pruebas. Codex mantiene
sus roles con sandbox de lectura y la misma restricción en sus instrucciones.

Las instrucciones y skills orientan el comportamiento. Los modos de autonomía no
imponen técnicamente las aprobaciones humanas para publicar o borrar: esas reglas
siguen siendo parte del contrato. Las políticas administradas tienen prioridad.

## Linux: instalar y desplegar

Paquetes declarados: `claude-code` (CachyOS), `claude-desktop-extra` (AUR) y Codex
existente. Desktop Extra se construye con Shelly a partir de la receta revisada;
Pacman verifica el paquete nativo y gestiona ambas instalaciones. La procedencia
de esta entrega está en `ai/runtime-sources.json`. No se añade un repositorio de
terceros, no se instala Cowork ni se configura control del ordenador.

```bash
python3 scripts/render-ai.py
just lint
just check
just plan
just apply
just ai-plan
just ai-sync
just ai-check
```

Revisa las operaciones antes de aplicar. `just apply` gestiona la composición
Linux existente; `ai-sync` gestiona los dos clientes en su propia transacción.
No ejecutes Stow contra `ai/` ni desde un worktree secundario.

El CLI oficial de navegador está fijado a la versión de la skill vendorizada:

```bash
npm install --global @playwright/cli@0.1.21
playwright-cli --version
```

Usa el prefijo npm de usuario. No ejecutes `playwright-cli install --skills` encima
de las skills gestionadas: cambiaría su propiedad. La versión, commit, licencia y
checksums de la fuente están en `ai/skills/playwright-cli/SOURCE.json`.

Desktop Extra y el CLI del sistema pueden usar versiones distintas del motor.
No fuerces `CLAUDE_CODE_LOCAL_BINARY`: Desktop gestiona su versión compatible.
Abre Claude, inicia sesión Pro/Max y, en **Settings → Claude Code**, activa
**Allow bypass permissions mode**. Después selecciona **Bypass permissions**
en una sesión nueva. El ajuste de Desktop no se sustituye manipulando archivos
internos sin contrato. Comprueba el modo visible y las políticas del equipo.

`claude auth login` autentica el CLI por separado si `claude auth status` indica
que falta la sesión. No copies tokens entre clientes o equipos.

## Windows del trabajo

Usa el [instalador oficial de Claude Desktop](https://claude.com/download),
Windows nativo, Git para Windows y Python 3.11 o posterior. Reinicia Desktop
tras instalar herramientas o cambiar PATH: no lee el perfil de PowerShell.
Respeta las políticas de la empresa; no hace falta Stow, WSL, administrador ni
crear enlaces simbólicos para desplegar la configuración.

Clona estos dotfiles en una carpeta local real. No uses una junction, un enlace
ni un directorio redirigido para el HOME o las carpetas gestionadas.

```powershell
cd 'C:\Users\tu-usuario\dotfiles'
.\scripts\ai-setup.ps1 -Mode plan
.\scripts\ai-setup.ps1 -Mode apply
.\scripts\ai-setup.ps1 -Mode check
```

El valor predeterminado despliega solo Claude. `-Clients both` conserva también
un Codex instalado. `-TargetHome 'C:\Users\Nombre Con Espacios'` permite un HOME
explícito para una prueba. Cada skill se copia y se verifica; una edición local
posterior bloquea su sobrescritura. Revisa/aprueba la ejecución del script según
la política corporativa, sin cambiar ni eludir la política de PowerShell.
Las exportaciones de skills excluyen `__pycache__`, `.pyc` y `.pyo` generados
durante pruebas. Los respaldos conservan snapshots completos para el rollback.

Para Playwright instala Node LTS y ejecuta `npm.cmd install --global
@playwright/cli@0.1.21`. Usa `playwright-cli.cmd` si la política impide los wrappers
PowerShell. El instalador de configuración no instala paquetes corporativos ni
altera modelos, esfuerzo, credenciales, plugins ni archivos administrados.

En Code de Desktop activa el ajuste de bypass descrito arriba si la política lo
permite. Comprueba `/memory`, `/skills`, `/agents`, `/mcp` y `/permissions` en una
sesión nueva. Esta comprobación GUI debe hacerse en el equipo del trabajo; las
pruebas portables ejecutadas desde Linux no la sustituyen. CI incluye un job
Windows que prueba copias, rutas con espacios, PowerShell y junctions.

Claude Code reciente admite ambas instrucciones con la opción builtin
`instructionFiles=claude-md-and-agents-md`. Si un proyecto usa una versión antigua,
su `CLAUDE.md` puede importar `@AGENTS.md`; no dupliques el contenido. No se crean
ni sobrescriben instrucciones en proyectos ajenos automáticamente.

## Cambiar de proveedor

```bash
ai-provider get
ai-provider set claude
ai-provider set codex
```

En el lanzador `/cmd`, usa **IA predeterminada — Claude** o **IA predeterminada —
Codex**. La preferencia se guarda como `[ai] provider = "claude" | "codex"` en
`~/.config/dotfiles/host.toml`. No se versiona ni se comparte con Windows.

Hyper+W, el arranque, Hyper+P/capturas y `/proj` usan el mismo resolvedor. Cambiar
la preferencia no cierra ni lanza sesiones. `/proj-actions` y `/cmd` conservan
accesos explícitos a ambos clientes. Los espacios de ventanas están separados.
Una captura se copia al portapapeles y enfoca la app; no envía una conversación.

Los escritorios no ofrecen aquí un contrato verificado para abrir un repositorio
por argumento. Las acciones de proyectos enfocan la app y abren el terminal en
el repositorio. Selecciona la carpeta dentro de Desktop. Si falta Desktop, se
abre el CLI del mismo proveedor en Ghostty/Zellij. Un fallo de inicio de Desktop
se muestra como error; no cambia de proveedor silenciosamente.

Solo se arranca automáticamente el proveedor seleccionado. Si necesitas que
una automatización local del otro cliente se ejecute, mantén ese cliente abierto.
Las notificaciones de fin de turno son genéricas y no incluyen conversaciones,
rutas, identificadores ni respuestas.

## MCP y permisos

- `linear`: `https://mcp.linear.app/mcp/readonly`; necesita OAuth por cliente.
- `openaiDeveloperDocs`: `https://developers.openai.com/mcp`.
- GitHub: `gh`, con su autenticación local.
- Codex mantiene `linear-write` desactivado. Claude rechaza una conexión persistente
  con ese nombre; la escritura se carga solo con un JSON temporal mediante
  `claude --mcp-config RUTA`. Sigue `linear-workflow` y la confirmación fresca del
  destino/campos; no habilites escritura global por comodidad.

No se migran cuentas, tokens ni conexiones corporativas. Una conexión con el
mismo nombre y otro endpoint bloquea la aplicación para evitar sustituirla.
`component-atlas` se retira con respaldo; si reaparece después, se detecta como
conflicto. También se retiran únicamente sus enlaces exactos conocidos.

## Actualizar sin divergencias

1. Actualiza paquetes con Shelly/Pacman en Linux y el instalador oficial en Windows.
2. Revisa las novedades oficiales que afecten a settings, instrucciones, skills,
   hooks o roles. La configuración se revisa bajo demanda, no por una tarea automática.
3. Edita `ai/`, adapta el formato específico si cambió y ejecuta
   `python3 scripts/render-ai.py` para regenerar los archivos Codex versionados.
4. Ejecuta pruebas, `just lint`, `just check`, `just plan`, `just ai-plan`.
5. Aplica y ejecuta `just ai-check`; abre una sesión nueva de ambos clientes.
6. Antes del cambio mensual deja una continuidad breve en `docs/work/<tarea>.md`:
   objetivo, decisiones, estado Git, comprobaciones fechadas y siguiente paso.
   El siguiente cliente lee ese documento y verifica el estado actual.

No edites las copias generadas. Se fusionan solo claves gestionadas; modelos,
esfuerzo, hooks ajenos, proyectos y preferencias locales sobreviven a la fusión.
Una modificación posterior de una clave gestionada, role o skill copiada bloquea
la aplicación. Revisa el cambio y concílialo con su fuente; no hay `--force`.

## Backups y recuperación

`ai-sync` imprime solo rutas/tipos y la ubicación del respaldo, nunca los valores
de configuración. Linux guarda transacciones privadas en
`~/.local/state/dotfiles/ai/backups/`; Windows en
`%USERPROFILE%\AppData\Local\dotfiles\ai\backups\`.
Los backups contienen configuración privada: no los copies al repositorio.

```bash
python3 scripts/sync-ai.py rollback --backup /ruta/exacta/al/backup
```

```powershell
.\scripts\ai-setup.ps1 -Mode rollback -Backup 'C:\ruta exacta\al backup'
```

Rollback comprueba que cada destino conserva el contenido posterior o ya
restaurado. Si hubo modificaciones ajenas, se detiene. También puede recuperar
un diario interrumpido o una restauración automática fallida. No borres backups
ni el manifiesto para resolver un conflicto. Si una interrupción dejó `sync.lock`,
comprueba que no hay otra sincronización activa antes de retirar ese archivo exacto.
La transacción de Stow tiene su propio rollback y respaldo, independientes.

## Tessera, proveedor de decisión y dirección visual

Los planes aportados en `planes-tessera-jev-claude-codex.zip` quedan como contexto
para esta fase, confirmada por el usuario el 27 de septiembre de 2026.
Tessera sustituye la responsabilidad de catálogo de Atlas dentro del workflow
existente. Es la base de conocimiento local por proyecto de componentes y
utilidades, ampliable conforme se implementa. Catálogos, tareas e historial se
guardan fuera de Git, separados por proyecto bajo XDG/LOCALAPPDATA. En el trabajo
no se crea `.tessera` ni se llevan fichas al repositorio corporativo o a dotfiles
personal. `locate` resuelve el almacén y `changes` detecta cambios de compañeros
ya presentes en el checkout para que el agente actualice las fichas antes de
consultar al motor. Memoria, continuidad y workflow
conservan sus propietarios. La retirada de la skill Atlas `visual-direction`
no elimina el checkout, datos, referencias ni temas visuales de Atlas.

`status` distingue sin inicializar, inicializando, actualización pendiente,
revisión completa necesaria, listo y bloqueado. `init`/`scan` inventarían
el árbol Git excluyendo tests por ruta antes de leerlos; `skeleton` deja en el
almacén externo fuentes candidatas, exports y primeros usos reales como punto de
partida; el agente revisa por tandas y `finalize` valida esa cobertura. No analizar tests ni citarlos como evidencia.
El flujo normal usa `prepare --require-ready`. Un catálogo piloto actualizado
no se presenta como proyecto completo. Procedimiento y límites de cobertura en
[lifecycle.md](../ai/skills/tessera/references/lifecycle.md).

Para consultar catálogos, inventario y decisiones de forma visual existe
[Tessera Studio](https://github.com/jesus-molano/tessera-studio), un repositorio
aparte: `python -m tessera_studio --open`. Solo lee el almacén local, escucha en
`127.0.0.1`, no escribe y no sirve texto de fuentes. Detecta también el almacén
virtualizado de apps MSIX como Claude Desktop en Windows. Contiene la herramienta,
nunca catálogos; dotfiles tampoco versiona datos de proyectos.

La [skill neutral Tessera](../ai/skills/tessera/SKILL.md) enruta las decisiones de
reutilizar, modificar, envolver o crear. Jev de TypeSafe es su primer adaptador
real; catálogo, contexto e historial no dependen de ese proveedor. Cambiarlo
requiere otro adaptador verificado, no rehacer Tessera ni simular una futura API
de Claude o Codex. El código no está integrado como servicio permanente.

Primer piloto: `Expenses-Log-App`, 14 fichas de UI compartida y utilidad `cn`.
Se prepara en `ai/tessera/pilots/expenses-log-app`; no se ha escrito en la app.
Cuatro escenarios se ejecutaron contra Jev con todas las fichas: reutilizar,
modificar, envolver y crear. Consumo compacto: unos 5.500 tokens por caso.
El caso de botón mostró ambigüedad; no es una prueba general de calidad.
Kev tiene adaptador con la misma entrada y runtime local probado en Linux/CUDA.
Kev-0.8B se abstuvo en los cuatro casos: sigue siendo experimental, sin
equivalencia de calidad demostrada. Código y estilos completos quedan como evidencia
local; los motores reciben fichas, contratos y restricciones sin top-k.
Contrato, comandos y límites en la
[referencia de la skill](../ai/skills/tessera/references/contract.md).
Estado verificable y continuación en [docs/work/tessera-jev.md](work/tessera-jev.md).
La instalación de Kev se repite por equipo; el runtime, pesos y claves no se
versionan. El [prompt para el PC del trabajo](work/tessera-work-pc.md) coordina
actualización, despliegue de skills e instalación según su propio hardware.

Secuencia de continuación:

1. Usar Jev como motor habitual y conservar Kev-0.8B como alternativa local.
   Las pruebas comparadas están registradas; no repetirlas automáticamente.
   En el PC del trabajo elegir Kev según su hardware mediante el prompt.
   Cada motor recibe todas las fichas; no hay filtros ni top-k en Tessera.
2. Revisar las decisiones contra contratos y consumidores fuera de tests. Completar
   cobertura del proyecto cuando la tarea la requiera; separar curación,
   evidencia derivada y explicación atribuida al agente.
3. Incorporar el catálogo al almacenamiento local externo del proyecto y
   desplegar la skill desde la fuente canónica después de validar.
4. Recuperar `visual-direction` como capacidad independiente, con referencias
   compartidas y sin dependencia de Atlas; no fusionarla con Tessera.
5. Probar reutilización, modificación, wrappers y creación con ambos clientes. Añadir Figma
   y automatización solo cuando el piloto demuestre una necesidad concreta.

## Fuentes de compatibilidad

Consultadas para esta entrega: [Desktop](https://code.claude.com/docs/en/desktop),
[Linux](https://code.claude.com/docs/en/desktop-linux),
[instrucciones](https://code.claude.com/docs/en/memory),
[skills](https://code.claude.com/docs/en/skills),
[subagentes](https://code.claude.com/docs/en/sub-agents),
[hooks](https://code.claude.com/docs/en/hooks),
[Desktop Extra](https://github.com/patrickjaja/claude-desktop-extra) y
[Playwright CLI](https://github.com/microsoft/playwright-cli).
