return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-mocha" },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = "mocha",
      default_integrations = true,
      integrations = {
        aerial = true,
        blink_cmp = true,
        dap = true,
        dap_ui = true,
        flash = true,
        gitsigns = true,
        mason = true,
        neotree = true,
        native_lsp = { enabled = true },
        noice = true,
        snacks = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
  },
}
