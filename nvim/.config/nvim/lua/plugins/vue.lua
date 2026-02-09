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
}
