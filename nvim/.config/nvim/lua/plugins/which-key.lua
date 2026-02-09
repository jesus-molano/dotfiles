return {
  {
    "folke/which-key.nvim",

    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,

    opts = {
      preset = "helix",
      delay = 100,

      triggers = {
        { "<auto>", mode = "nxsoc" },
      },

      plugins = {
        marks = true,
        registers = true,
        spelling = {
          enabled = true,
          suggestions = 20,
        },
        presets = {
          operators = true,
          motions = true,
          text_objects = true,
          windows = true,
          nav = true,
          z = true,
          g = true,
        },
      },

      spec = {
        { "<leader>a", group = "ai" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "file/find" },
        { "<leader>g", group = "git" },
        { "<leader>q", group = "quit/session" },
        { "<leader>s", group = "search" },
        { "<leader>u", group = "ui/toggle" },
        { "<leader>w", group = "windows" },
        { "<leader>x", group = "diagnostics/quickfix" },
        { "<leader>y", group = "yank" },
        { "[", group = "prev" },
        { "]", group = "next" },
        { "g", group = "goto" },
        { "z", group = "fold/spelling/view" },
        { "<leader>", group = "leader", mode = { "v" } },
        { "<leader>a", group = "ai", mode = { "v" } },
      },
    },
  },
}
