return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = "mocha",
      integrations = {
        flash = true,
        gitsigns = true,
        mini = true,
        noice = true,
        notify = true,
        snacks = true,
        treesitter_context = true,
        which_key = true,
      },
    },
  },
}
