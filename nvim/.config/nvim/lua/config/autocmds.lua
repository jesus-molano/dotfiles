local autocmd = vim.api.nvim_create_autocmd

-- Quitar trailing whitespace al guardar
autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    if vim.bo.filetype == "markdown" then
      return
    end
    local save = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(save)
  end,
})

-- Desactivar auto-comment en nueva línea
autocmd("BufEnter", {
  callback = function()
    vim.opt_local.formatoptions:remove({ "o", "r" })
  end,
})
