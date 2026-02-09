return {
  { "nvim-mini/mini.files", enabled = false },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      close_if_last_window = true,
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = { ".git", "node_modules", ".nuxt", ".output", ".next", "dist" },
        },
      },
      window = {
        width = 35,
      },
    },
  },
}
