local M = {}

local severity_names = {
  [vim.diagnostic.severity.ERROR] = "ERROR",
  [vim.diagnostic.severity.WARN] = "WARN",
  [vim.diagnostic.severity.INFO] = "INFO",
  [vim.diagnostic.severity.HINT] = "HINT",
}

local function current_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil
  end
  return vim.fs.normalize(name)
end

local function visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  if start_line == 0 or end_line == 0 then
    return nil
  end
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  -- getregion handles inclusive byte columns, UTF-8 and block/line selections.
  local text = vim.fn.getregion(start_pos, end_pos, {
    type = vim.fn.visualmode(),
    exclusive = false,
  })
  return {
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
    text = table.concat(text, "\n"),
  }
end

local function diagnostics_at_cursor(line)
  local diagnostics = vim.diagnostic.get(0, { lnum = line - 1 })
  if #diagnostics == 0 then
    return nil
  end

  local lines = { "Diagnósticos:" }
  for _, diagnostic in ipairs(diagnostics) do
    local severity = severity_names[diagnostic.severity] or "INFO"
    local message = diagnostic.message:gsub("\n", " ")
    table.insert(lines, string.format("- [%s] %s", severity, message))
  end
  return lines
end

local function build_context(include_selection)
  local file = current_file()
  if not file then
    vim.notify("El buffer actual no tiene una ruta de archivo", vim.log.levels.WARN)
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = {
    "Contexto de Neovim para Orca",
    string.format("Archivo: %s", file),
  }

  local selection = include_selection and visual_selection() or nil
  if selection then
    table.insert(
      lines,
      string.format(
        "Rango: L%d:C%d-L%d:C%d",
        selection.start_line,
        selection.start_col,
        selection.end_line,
        selection.end_col
      )
    )
    table.insert(lines, "Selección:")
    table.insert(lines, "```")
    vim.list_extend(lines, vim.split(selection.text, "\n", { plain = true }))
    table.insert(lines, "```")
  else
    table.insert(lines, string.format("Línea: L%d:C%d", cursor[1], cursor[2] + 1))
    local diagnostics = diagnostics_at_cursor(cursor[1])
    if diagnostics then
      vim.list_extend(lines, diagnostics)
    end
  end

  return table.concat(lines, "\n")
end

local function copy_to_clipboard(context)
  vim.fn.setreg("+", context)
  vim.fn.setreg("*", context)
end

local function focus_orca()
  if vim.fn.executable("hypr-orca") == 0 then
    vim.notify("No se encontró hypr-orca en PATH", vim.log.levels.ERROR)
    return false
  end

  vim.fn.jobstart({ "hypr-orca" }, { detach = true })
  return true
end

---@param opts? { selection?: boolean, focus?: boolean }
---@return string|nil
function M.copy_context(opts)
  opts = opts or {}
  local context = build_context(opts.selection == true)
  if not context then
    return nil
  end

  copy_to_clipboard(context)
  if opts.focus then
    focus_orca()
  end

  vim.notify(opts.focus and "Contexto copiado y Orca enfocado" or "Contexto copiado", vim.log.levels.INFO)
  return context
end

function M.copy_context_and_focus()
  return M.copy_context({ focus = true })
end

function M.copy_selection_and_focus()
  return M.copy_context({ selection = true, focus = true })
end

return M
