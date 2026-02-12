vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- AI: Habilitar completions de AI en blink.cmp
vim.g.ai_cmp = true

-- Prettier si tiene config, sino Biome
vim.g.lazyvim_prettier_needs_config = true

-- Overrides de LazyVim defaults
-- Sync yank with both primary selection (*) and clipboard (+)
-- Must run via LazyVimOptions autocmd so it executes AFTER LazyVim sets its
-- defaults but BEFORE lazy_clipboard is captured for deferred restore.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyVimOptions",
  callback = function()
    vim.opt.clipboard = "unnamed,unnamedplus"
  end,
})
vim.opt.scrolloff = 8
vim.opt.splitkeep = "screen"
vim.opt.pumblend = 0

-- Inlay hints (tipos inferidos inline para TypeScript)
vim.lsp.inlay_hint.enable(true)
