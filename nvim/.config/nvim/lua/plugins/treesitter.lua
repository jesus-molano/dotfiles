return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "css",
        "fish",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "scss",
        "tsx",
        "typescript",
        "vue",
        "yaml",
        "toml",
        "graphql",
      },
    },
  },
  -- Sticky scroll: shows current function/scope at top
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = {
      max_lines = 3,
      multiline_threshold = 1,
    },
    keys = {
      {
        "<leader>ut",
        function()
          require("treesitter-context").toggle()
        end,
        desc = "Toggle Treesitter Context",
      },
    },
  },
}
