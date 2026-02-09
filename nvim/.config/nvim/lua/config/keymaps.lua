local map = vim.keymap.set

-- Copiar utilidades
map("n", "<leader>yy", "<cmd>%y+<cr>", { desc = "Copy entire file" })
map("n", "<leader>ya", '<cmd>let @+ = expand("%:p")<cr>', { desc = "Copy absolute path" })
map("n", "<leader>yr", '<cmd>let @+ = expand("%:.")<cr>', { desc = "Copy relative path" })
