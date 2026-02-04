return {
  -- mini.files as file explorer (lightweight alternative to neo-tree)
  {
    "nvim-mini/mini.files",
    opts = {
      windows = {
        preview = true,
        width_preview = 40,
      },
    },
    keys = {
      {
        "<leader>e",
        function()
          require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
        end,
        desc = "Open mini.files (current file)",
      },
      {
        "<leader>E",
        function()
          require("mini.files").open(vim.uv.cwd(), true)
        end,
        desc = "Open mini.files (cwd)",
      },
    },
  },
  -- Disable neo-tree since we use mini.files
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
}
