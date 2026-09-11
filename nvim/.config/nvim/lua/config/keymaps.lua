local map = vim.keymap.set

-- Copiar utilidades
map("n", "<leader>yy", "<cmd>%y+<cr>", { desc = "Copy entire file" })
map("n", "<leader>ya", '<cmd>let @+ = expand("%:p")<cr>', { desc = "Copy absolute path" })
map("n", "<leader>yr", '<cmd>let @+ = expand("%:.")<cr>', { desc = "Copy relative path" })

-- Codex stays outside Neovim. These mappings copy precise editor context and
-- focus the existing ChatGPT Community window through the desktop launcher.
map("n", "<leader>ao", function()
  require("config.orca").copy_context_and_focus()
end, { desc = "Copy context and focus ChatGPT Community" })
map("x", "<leader>ao", function()
  require("config.orca").copy_selection_and_focus()
end, { desc = "Copy selection and focus ChatGPT Community" })
