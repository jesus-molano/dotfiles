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
      color_overrides = {
        mocha = (function()
          local fallback = {
            primary = "#ff5b4d",
            secondary = "#83a7c4",
            tertiary = "#c4a663",
            error = "#d86f91",
            surface = "#14171c",
            surface_variant = "#1b1f26",
            outline = "#454b57",
            foreground = "#f1f3f5",
            muted = "#a8afba",
            background = "#090a0d",
            green = "#73bd8a",
            yellow = "#d8aa5d",
            magenta = "#b98eaa",
            cyan = "#7fa4c0",
          }

          local palette_path = vim.fn.expand("~/.config/noctalia/palettes/ProjectAtlas.json")
          local ok_read, lines = pcall(vim.fn.readfile, palette_path)
          if ok_read then
            local ok_decode, palette = pcall(vim.json.decode, table.concat(lines, "\n"))
            local dark = ok_decode and palette and palette.dark
            local terminal = dark and dark.terminal
            if dark and terminal then
              fallback.primary = dark.mPrimary or fallback.primary
              fallback.secondary = dark.mSecondary or fallback.secondary
              fallback.tertiary = dark.mTertiary or fallback.tertiary
              fallback.error = dark.mError or fallback.error
              fallback.surface = dark.mSurface or fallback.surface
              fallback.surface_variant = dark.mSurfaceVariant or fallback.surface_variant
              fallback.outline = dark.mOutline or fallback.outline
              fallback.foreground = terminal.foreground or fallback.foreground
              fallback.muted = dark.mOnSurfaceVariant or fallback.muted
              fallback.background = terminal.background or fallback.background
              fallback.green = terminal.normal and terminal.normal.green or fallback.green
              fallback.yellow = terminal.normal and terminal.normal.yellow or fallback.yellow
              fallback.magenta = terminal.normal and terminal.normal.magenta or fallback.magenta
              fallback.cyan = terminal.normal and terminal.normal.cyan or fallback.cyan
            end
          end

          return {
            rosewater = fallback.tertiary,
            flamingo = fallback.error,
            pink = fallback.magenta,
            mauve = fallback.magenta,
            red = fallback.error,
            maroon = fallback.error,
            peach = fallback.primary,
            yellow = fallback.yellow,
            green = fallback.green,
            teal = fallback.cyan,
            sky = fallback.cyan,
            sapphire = fallback.secondary,
            blue = fallback.secondary,
            lavender = fallback.primary,
            text = fallback.foreground,
            subtext1 = fallback.muted,
            subtext0 = fallback.muted,
            overlay2 = fallback.muted,
            overlay1 = fallback.outline,
            overlay0 = fallback.outline,
            surface2 = fallback.outline,
            surface1 = fallback.surface_variant,
            surface0 = fallback.surface,
            base = fallback.background,
            mantle = fallback.background,
            crust = fallback.background,
          }
        end)(),
      },
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
        mini = { enabled = true },
        snacks = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
  },
}
