return {
  -- Fix: Go to Definition en Nuxt navega a .d.ts en vez del source real
  {
    "catgoose/vue-goto-definition.nvim",
    ft = "vue",
    opts = {
      filters = {
        auto_imports = true,
        auto_components = true,
        import_same_file = true,
        declaration = true,
        duplicate_filename = true,
      },
    },
  },

  -- Desactivar formateo de Volar (vue_ls) — ESLint maneja el formateo via @nuxt/eslint stylistic
  {
    "neovim/nvim-lspconfig",
    opts = {
      setup = {
        vue_ls = function(_, opts)
          local original_on_attach = opts.on_attach
          opts.on_attach = function(client, bufnr)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
            if original_on_attach then
              original_on_attach(client, bufnr)
            end
          end
        end,
      },
    },
  },
}
