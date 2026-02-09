vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- AI: Habilitar completions de AI en blink.cmp
vim.g.ai_cmp = true

-- Biome tiene prioridad sobre Prettier
vim.g.lazyvim_prettier_needs_config = true

-- Overrides de LazyVim defaults
vim.opt.scrolloff = 8
vim.opt.splitkeep = "screen"
vim.opt.pumblend = 0
