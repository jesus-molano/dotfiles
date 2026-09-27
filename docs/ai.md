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

Hay 16 skills propias y la skill oficial `playwright-cli`. En Windows se excluye
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

## Siguiente fase: Tessera, JEV y dirección visual

Los planes aportados en `planes-tessera-jev-claude-codex.zip` quedan como contexto
para una fase posterior, confirmada por el usuario el 27 de septiembre de 2026.
Esta entrega prepara su independencia del proveedor, pero no instala ni simula
Tessera/JEV. La retirada de la skill Atlas `visual-direction` no elimina el
checkout, datos, referencias ni temas visuales de Atlas.

Orden del siguiente trabajo:

1. Identificar la implementación real de JEV y verificar cómo recibe contexto y
   devuelve decisiones. Acordar su contrato antes de diseñar alrededor de él.
2. Elegir un proyecto piloto e inventariar componentes/utilidades con contratos,
   usos y pruebas. Separar fichas curadas, datos derivados y decisiones.
3. Crear un catálogo Tessera local, versionable y neutral. JEV decide reutilizar,
   adaptar o crear; evitar filtros o límites arbitrarios antes de medirlo.
4. Recuperar `visual-direction` como capacidad independiente, con referencias
   compartidas y sin dependencia de Atlas; no fusionarla con Tessera.
5. Probar reutilización, adaptación y creación con ambos clientes. Añadir Figma
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
