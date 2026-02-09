# Guia Completa de tu Neovim Config

> LazyVim + 50 plugins | Catppuccin Mocha | Vue/Nuxt + React/Next stack

---

## 1. Fundamentos

| Tecla | Funcion |
|-------|---------|
| `Space` | Leader key |
| `\` | Local leader |
| `Space` + esperar 100ms | which-key muestra TODOS los atajos disponibles |

**Tip**: which-key usa preset `helix` — los atajos se muestran en formato horizontal compacto. Si no recuerdas un atajo, pulsa `<Space>` y espera.

---

## 2. Atajos Personalizados (keymaps.lua)

| Atajo | Accion |
|-------|--------|
| `<leader>yy` | Copiar contenido entero del archivo al clipboard |
| `<leader>ya` | Copiar ruta absoluta del archivo |
| `<leader>yr` | Copiar ruta relativa del archivo |

---

## 3. AI — Claude Code + Copilot

### Claude Code (`<leader>a`)

| Atajo | Accion |
|-------|--------|
| `<leader>ac` | Abrir/cerrar terminal de Claude Code (panel derecho, 35%) |
| `<leader>af` | Dar foco al panel de Claude |
| `<leader>ar` | Reanudar conversacion anterior (`--resume`) |
| `<leader>aC` | Continuar ultima conversacion (`--continue`) |
| `<leader>am` | Cambiar modelo (Opus/Sonnet/Haiku) |
| `<leader>ab` | Enviar buffer actual como contexto a Claude |
| `<leader>as` | **Visual mode**: enviar seleccion a Claude |
| `<leader>as` | **En neo-tree**: agregar archivo del arbol a Claude |
| `<leader>aa` | Aceptar diff propuesto por Claude |
| `<leader>ad` | Rechazar diff propuesto por Claude |

**Tips**:
- Los diffs de Claude se abren en nueva tab — revisalos antes de aceptar
- Selecciona codigo en visual mode y `<leader>as` para preguntar sobre un fragmento especifico
- Usa `<leader>ab` para dar contexto del archivo antes de hacer preguntas

### Copilot (viene con el extra `ai.copilot`)

- Sugerencias inline automaticas mientras escribes
- `Tab` para aceptar sugerencia
- `<C-]>` para descartar
- Las completions de Copilot aparecen en blink.cmp (`vim.g.ai_cmp = true`)

---

## 4. Navegacion de Archivos

### Neo-tree (`<leader>e` / `<leader>E`)

| Atajo | Accion |
|-------|--------|
| `<leader>e` | Toggle explorador de archivos (sigue archivo actual) |
| `<leader>E` | Abrir explorador en cwd |
| `a` | Crear archivo/carpeta (dentro de neo-tree) |
| `d` | Eliminar archivo |
| `r` | Renombrar |
| `c` | Copiar |
| `m` | Mover |
| `y` | Copiar nombre |
| `Y` | Copiar ruta relativa |
| `P` | Pegar |
| `/` | Filtrar archivos |

**Config notable**:
- Muestra dotfiles y archivos gitignored
- Oculta: `.git`, `node_modules`, `.nuxt`, `.output`, `.next`, `dist`
- Ancho: 35 columnas
- Se cierra automaticamente si es la ultima ventana

### Snacks Picker (fuzzy finder)

| Atajo | Accion |
|-------|--------|
| `<leader>ff` | Buscar archivos |
| `<leader>fg` | Buscar texto (grep) en proyecto |
| `<leader>fb` | Buscar en buffers abiertos |
| `<leader>fr` | Archivos recientes |
| `<leader>f/` | Buscar en buffer actual |
| `<leader>fc` | Buscar en config de Neovim |
| `<leader>fs` | Buscar simbolos (documento actual) |
| `<leader>fS` | Buscar simbolos (workspace) |

### Flash.nvim (movimiento rapido)

| Atajo | Accion |
|-------|--------|
| `s` | Flash jump — escribe 2 chars y salta |
| `S` | Flash treesitter — selecciona nodos del AST |
| `r` | Flash en modo operator-pending (dentro de `d`, `c`, `y`) |

**Tip**: `s` + 2 caracteres te lleva a cualquier coincidencia visible. Mucho mas rapido que buscar con `/`.

---

## 5. LSP — Codigo Inteligente

### Navegacion de codigo

| Atajo | Accion |
|-------|--------|
| `gd` | Ir a definicion |
| `gD` | Ir a declaracion |
| `gr` | Ver referencias |
| `gI` | Ir a implementacion |
| `gy` | Ir a type definition |
| `K` | Hover — muestra documentacion |
| `gK` | Signature help |

### Acciones de codigo (`<leader>c`)

| Atajo | Accion |
|-------|--------|
| `<leader>ca` | Code actions (refactors, quick fixes) |
| `<leader>cr` | Renombrar simbolo (en todo el proyecto) |
| `<leader>cd` | Line diagnostics |
| `<leader>cf` | Formatear archivo/seleccion |
| `<leader>cl` | LSP info |

### Diagnosticos (`<leader>x`)

| Atajo | Accion |
|-------|--------|
| `<leader>xx` | Toggle Trouble — lista de diagnosticos |
| `<leader>xX` | Trouble buffer actual |
| `<leader>xL` | Location list |
| `<leader>xQ` | Quickfix list |
| `]d` / `[d` | Siguiente/anterior diagnostico |
| `]e` / `[e` | Siguiente/anterior error |
| `]w` / `[w` | Siguiente/anterior warning |

### Formateo automatico

Tu config tiene una estrategia inteligente de formateo:

1. **Prettier** se usa SI existe config en el proyecto (`.prettierrc`, `prettier.config.*`, etc.)
2. **Biome** se usa como fallback SI existe `biome.json` y NO hay config de Prettier ni ESLint
3. `stop_after_first = true` — solo ejecuta el primer formatter disponible

**Lenguajes soportados**: vue, ts, js, tsx, jsx, json, jsonc, css, html, yaml, markdown, scss, graphql

### Vue/Nuxt especifico
- `vue-goto-definition.nvim` — `gd` en archivos `.vue` va al source real, no a `.d.ts`
- Soporta auto-imports y auto-components de Nuxt

---

## 6. Git (`<leader>g`)

| Atajo | Accion |
|-------|--------|
| `<leader>gg` | LazyGit (TUI de git completo) |
| `<leader>gf` | Buscar archivos git |
| `<leader>gl` | Log de git |
| `<leader>gs` | Git status |
| `<leader>gb` | Git blame (linea actual) |
| `<leader>gd` | Diff del archivo |
| `]h` / `[h` | Siguiente/anterior hunk (cambio) |
| `<leader>ghs` | Stage hunk |
| `<leader>ghr` | Reset hunk |
| `<leader>ghp` | Preview hunk |
| `<leader>ghb` | Blame linea |

**Tip**: LazyGit (`<leader>gg`) es un gestor de git completo — puedes hacer commits, push, pull, rebase, cherry-pick, resolver conflictos, todo sin salir de Neovim.

---

## 7. Buffers y Ventanas

### Buffers (`<leader>b`)

| Atajo | Accion |
|-------|--------|
| `<S-h>` / `<S-l>` | Buffer anterior/siguiente (Shift+H/L) |
| `<leader>bd` | Cerrar buffer actual |
| `<leader>bD` | Cerrar otros buffers |
| `<leader>bb` | Cambiar a buffer anterior |
| `<leader>bp` | Pin/unpin buffer |

### Ventanas (`<leader>w`)

| Atajo | Accion |
|-------|--------|
| `<C-h/j/k/l>` | Mover entre ventanas (Ctrl+direccion) |
| `<leader>w-` | Split horizontal |
| `<leader>w\|` | Split vertical |
| `<leader>wd` | Cerrar ventana |
| `<leader>wm` | Maximizar ventana |
| `<C-Up/Down/Left/Right>` | Redimensionar ventana |

---

## 8. Buscar y Reemplazar

### Busqueda

| Atajo | Accion |
|-------|--------|
| `<leader>sg` | Grep en todo el proyecto (live) |
| `<leader>sw` | Buscar palabra bajo cursor |
| `<leader>ss` | Buscar simbolos |
| `<leader>sR` | Resume ultima busqueda |
| `<leader>sd` | Buscar diagnosticos |
| `<leader>st` | Buscar TODOs |

### Grug-far (buscar y reemplazar avanzado)

| Atajo | Accion |
|-------|--------|
| `<leader>sr` | Buscar y reemplazar (grug-far) |

**Tip**: grug-far permite buscar/reemplazar con regex en todo el proyecto, con preview en tiempo real.

---

## 9. Debugging (DAP)

| Atajo | Accion |
|-------|--------|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Breakpoint con condicion |
| `<leader>dc` | Continuar / iniciar debug |
| `<leader>dC` | Run to cursor |
| `<leader>di` | Step into |
| `<leader>do` | Step over |
| `<leader>dO` | Step out |
| `<leader>dp` | Pause |
| `<leader>dr` | Toggle REPL |
| `<leader>ds` | Session actual |
| `<leader>dt` | Terminar sesion |
| `<leader>du` | Toggle DAP UI |
| `<leader>dw` | Widgets |

**Tip**: DAP UI muestra variables, call stack, breakpoints y consola. El virtual text muestra valores inline en el codigo.

---

## 10. UI y Toggles (`<leader>u`)

| Atajo | Accion |
|-------|--------|
| `<leader>ut` | Toggle treesitter context (sticky scroll) |
| `<leader>uf` | Toggle formato automatico (global) |
| `<leader>uF` | Toggle formato automatico (buffer) |
| `<leader>uw` | Toggle word wrap |
| `<leader>ul` | Toggle numeros de linea |
| `<leader>uL` | Toggle numeros relativos |
| `<leader>ud` | Toggle diagnosticos |
| `<leader>uc` | Toggle conceal |
| `<leader>us` | Toggle spelling |
| `<leader>ui` | Inspect posicion (treesitter info) |
| `<leader>un` | Descartar notificaciones |

---

## 11. Aerial — Outline de Simbolos

| Atajo | Accion |
|-------|--------|
| `<leader>cs` | Toggle aerial (sidebar de simbolos) |
| `{` / `}` | Anterior/siguiente simbolo (dentro de aerial) |

**Tip**: Aerial muestra funciones, clases, variables del archivo actual en sidebar. Ideal para navegar archivos grandes.

---

## 12. Sesiones (`<leader>q`)

| Atajo | Accion |
|-------|--------|
| `<leader>qs` | Restaurar sesion (directorio actual) |
| `<leader>qS` | Seleccionar sesion |
| `<leader>ql` | Restaurar ultima sesion |
| `<leader>qd` | No guardar sesion actual |
| `<leader>qq` | Salir de Neovim |

**Tip**: persistence.nvim guarda sesiones automaticamente. Al abrir nvim en un directorio de proyecto, `<leader>qs` restaura exactamente donde lo dejaste.

---

## 13. TODO Comments

| Atajo | Accion |
|-------|--------|
| `<leader>st` | Buscar todos los TODOs del proyecto |
| `<leader>sT` | Buscar TODO/FIX/FIXME |
| `<leader>xt` | TODO en Trouble |
| `]t` / `[t` | Siguiente/anterior TODO |

Resalta automaticamente: `TODO`, `HACK`, `WARN`, `PERF`, `NOTE`, `FIX`, `FIXME`, `BUG`

---

## 14. Autocmds Personalizados

1. **Trailing whitespace**: se elimina al guardar (excepto markdown)
2. **Sin auto-comment**: al hacer `o` o `Enter` en una linea con comentario, la nueva linea NO es comentario

---

## 15. Tips Pro

### Navegacion rapida
- `<C-o>` / `<C-i>` — saltar atras/adelante en jump list
- `gd` luego `<C-o>` — ir a definicion y volver
- `s` + 2 chars — Flash jump a cualquier parte visible
- `%` — saltar entre parentesis/brackets/tags emparejados

### Productividad
- `<leader>gg` — LazyGit es mas rapido que la terminal para git
- `<leader>sg` — grep vivo es mas rapido que Ctrl+Shift+F de VSCode
- `<leader>ff` — fuzzy finder aprende tus archivos frecuentes
- `:Lazy` — gestionar plugins (update, clean, profile)
- `:Mason` — instalar/actualizar LSP servers, formatters, linters

### Treesitter context
- Las 3 lineas superiores muestran en que funcion/bloque estas
- `<leader>ut` para togglear si molesta
- Threshold de 5 lineas: solo muestra contexto para bloques largos

### Edicion rapida
- `gcc` — comentar/descomentar linea
- `gc` + motion — comentar seleccion/rango
- `<leader>ca` — code actions (auto-imports, extraer variable, etc.)
- `<leader>cr` — renombrar simbolo en todo el proyecto
- `ciw` / `ci"` / `ci{` — cambiar dentro de palabra/comillas/llaves
- `va{` — seleccionar bloque incluyendo llaves

### Mini plugins
- **mini.ai** — text objects mejorados (`a` = around, `i` = inside) con funciones, clases
- **mini.pairs** — auto-cierre de brackets, comillas
- **mini.hipatterns** — resalta colores hex inline (#ff0000 se ve en color)

---

## 16. Cheatsheet Rapida

```
NAVEGACION          CODIGO              GIT                 AI
<leader>ff files    gd definicion       <leader>gg lazygit  <leader>ac claude
<leader>fg grep     gr referencias      ]h next hunk        <leader>as enviar
<leader>e  tree     K  hover            <leader>ghs stage   <leader>ab buffer
s          flash    <leader>ca actions  <leader>gb blame    <leader>am modelo
<C-o>      back     <leader>cr rename   <leader>gd diff     Tab copilot

BUFFERS             UI                  DEBUG               BUSCAR
<S-h/l>   cambiar   <leader>ut context  <leader>db break    <leader>sg grep
<leader>bd cerrar   <leader>uf format   <leader>dc start    <leader>sr replace
<leader>bb prev     <leader>ud diags    <leader>di step in  <leader>st todos
```

---

## Verificacion

Para comprobar que todo funciona:
1. `nvim` → `:checkhealth` — revisar estado de todos los plugins
2. `:Lazy` — verificar que no hay errores en plugins
3. `:Mason` — verificar LSP servers instalados
4. `:LspInfo` en un archivo `.vue`/`.ts` — confirmar que volar/ts_ls estan activos
5. `<leader>ac` — verificar que Claude Code abre panel
6. `<leader>gg` — verificar que LazyGit funciona
7. `<leader>ut` — verificar treesitter context toggle
