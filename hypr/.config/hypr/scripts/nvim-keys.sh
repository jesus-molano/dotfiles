#!/bin/bash
set -uo pipefail
# Show Neovim/LazyVim keybindings cheatsheet in rofi

keys=$(cat <<'EOF'
── MOVIMIENTO ──────────────────────────────────────────────────────
s + 2chars              Flash jump — salta a cualquier parte visible
S                       Flash treesitter — selecciona nodos del AST
<C-o> / <C-i>           Saltar atrás/adelante en jump list
%                       Saltar entre paréntesis/brackets emparejados
gd → <C-o>              Ir a definición y volver
f/F + char              Saltar a carácter en la línea (adelante/atrás)
{ / }                   Párrafo anterior/siguiente

── EDICIÓN RÁPIDA ──────────────────────────────────────────────────
gcc                     Comentar/descomentar línea
gc + motion             Comentar selección/rango
ciw / ci" / ci{         Cambiar dentro de palabra/comillas/llaves
diw / di" / di{         Borrar dentro de palabra/comillas/llaves
va{ / va(               Seleccionar bloque incluyendo delimitador
<C-a> / <C-x>           Incrementar/decrementar número
.                       Repetir último cambio
u / <C-r>               Undo / Redo

── YANK / COPIAR (<leader>y) ──────────────────────────────────────
<leader>yy              Copiar contenido entero del archivo al clipboard
<leader>ya              Copiar ruta absoluta del archivo
<leader>yr              Copiar ruta relativa del archivo

── ARCHIVOS (<leader>f) ────────────────────────────────────────────
<leader>ff              Buscar archivos (fuzzy finder)
<leader>fg              Grep en proyecto (búsqueda de texto)
<leader>fb              Buscar en buffers abiertos
<leader>fr              Archivos recientes
<leader>fc              Buscar en config de Neovim
<leader>fs              Buscar símbolos (documento actual)
<leader>fS              Buscar símbolos (workspace)
<leader>e               Toggle neo-tree (explorador de archivos)
<leader>E               Neo-tree en cwd

── LSP / CÓDIGO ────────────────────────────────────────────────────
gd                      Ir a definición
gD                      Ir a declaración
gr                      Ver referencias
gI                      Ir a implementación
gy                      Ir a type definition
K                       Hover — documentación
gK                      Signature help
<leader>ca              Code actions (refactors, quick fixes)
<leader>cr              Renombrar símbolo en todo el proyecto
<leader>cd              Diagnósticos de línea
<leader>cf              Formatear archivo/selección
<leader>cl              LSP info
<leader>cs              Toggle aerial (outline de símbolos)

── DIAGNÓSTICOS (<leader>x) ────────────────────────────────────────
<leader>xx              Toggle Trouble — lista de diagnósticos
<leader>xX              Trouble buffer actual
<leader>xL              Location list
<leader>xQ              Quickfix list
]d / [d                 Siguiente/anterior diagnóstico
]e / [e                 Siguiente/anterior error
]w / [w                 Siguiente/anterior warning

── BUSCAR Y REEMPLAZAR (<leader>s) ─────────────────────────────────
<leader>sg              Grep en todo el proyecto (live)
<leader>sw              Buscar palabra bajo cursor
<leader>ss              Buscar símbolos
<leader>sr              Buscar y reemplazar (grug-far)
<leader>st              Buscar TODOs del proyecto
<leader>sR              Reanudar última búsqueda
<leader>sd              Buscar diagnósticos

── GIT (<leader>g) ─────────────────────────────────────────────────
<leader>gg              LazyGit (TUI completo)
<leader>gf              Buscar archivos git
<leader>gl              Git log
<leader>gs              Git status
<leader>gb              Git blame línea actual
<leader>gd              Diff del archivo
]h / [h                 Siguiente/anterior hunk
<leader>ghs             Stage hunk
<leader>ghr             Reset hunk
<leader>ghp             Preview hunk
<leader>ghb             Blame línea

── AI (<leader>a) ──────────────────────────────────────────────────
<leader>ac              Abrir/cerrar terminal Claude Code
<leader>af              Dar foco al panel de Claude
<leader>ar              Reanudar conversación anterior (--resume)
<leader>aC              Continuar última conversación (--continue)
<leader>am              Cambiar modelo (Opus/Sonnet/Haiku)
<leader>ab              Enviar buffer como contexto a Claude
<leader>as              Enviar selección a Claude (visual mode)
<leader>aa              Aceptar diff de Claude
<leader>ad              Rechazar diff de Claude
Tab                     Aceptar sugerencia de Copilot

── BUFFERS Y VENTANAS ──────────────────────────────────────────────
<S-h> / <S-l>           Buffer anterior/siguiente
<leader>bd              Cerrar buffer actual
<leader>bD              Cerrar otros buffers
<leader>bb              Cambiar a buffer anterior
<leader>bp              Pin/unpin buffer
<C-h/j/k/l>            Mover entre ventanas
<leader>w-              Split horizontal
<leader>w|              Split vertical
<leader>wd              Cerrar ventana
<leader>wm              Maximizar ventana

── TOGGLES (<leader>u) ─────────────────────────────────────────────
<leader>ut              Toggle treesitter context (sticky scroll)
<leader>uf              Toggle formato automático (global)
<leader>uF              Toggle formato automático (buffer)
<leader>uw              Toggle word wrap
<leader>ul              Toggle números de línea
<leader>uL              Toggle números relativos
<leader>ud              Toggle diagnósticos
<leader>uc              Toggle conceal
<leader>us              Toggle spelling
<leader>ui              Inspect posición (treesitter info)
<leader>un              Descartar notificaciones

── DEBUG (<leader>d) ───────────────────────────────────────────────
<leader>db              Toggle breakpoint
<leader>dB              Breakpoint con condición
<leader>dc              Continuar / iniciar debug
<leader>dC              Run to cursor
<leader>di              Step into
<leader>do              Step over
<leader>dO              Step out
<leader>dp              Pause
<leader>dr              Toggle REPL
<leader>ds              Session actual
<leader>dt              Terminar sesión
<leader>du              Toggle DAP UI
<leader>dw              Widgets

── OBSIDIAN (<leader>o) ────────────────────────────────────────────
<leader>on              Nueva nota
<leader>oo              Cambiar rápido entre notas
<leader>os              Buscar en vault
<leader>od              Nota diaria de hoy
<leader>oy              Nota de ayer
<leader>oT              Nota de mañana
<leader>ob              Backlinks de la nota actual
<leader>ol              Todos los links del vault
<leader>oL              Crear link desde selección (visual)
<leader>ot              Insertar template
<leader>op              Pegar imagen en nota
<leader>or              Renombrar nota
gf                      Seguir link bajo cursor (en markdown)

── TEST (<leader>t) ───────────────────────────────────────────────
<leader>tt              Ejecutar test más cercano
<leader>tT              Ejecutar tests del archivo
<leader>tr              Ejecutar últimos tests
<leader>ts              Toggle resumen de tests
<leader>to              Toggle output del test
<leader>tS              Stop tests
<leader>td              Debug test más cercano
<leader>tw              Toggle watch mode

── SESIONES (<leader>q) ────────────────────────────────────────────
<leader>qs              Restaurar sesión (directorio actual)
<leader>qS              Seleccionar sesión
<leader>ql              Restaurar última sesión
<leader>qd              No guardar sesión actual
<leader>qq              Salir de Neovim

── COMANDOS ÚTILES ─────────────────────────────────────────────────
:Lazy                   Gestionar plugins (update, clean, profile)
:Mason                  Instalar/actualizar LSP servers y formatters
:checkhealth            Revisar estado de todos los plugins
:LspInfo                Info del LSP activo en el buffer
EOF
)

echo "$keys" | rofi -dmenu -p " Neovim" -i -theme ~/.config/rofi/launchers/type-1/style-2.rasi -theme-str 'window { width: 850px; }'
