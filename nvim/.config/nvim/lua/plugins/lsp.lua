local prettier_configs = {
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.yml",
  ".prettierrc.yaml",
  ".prettierrc.json5",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  ".prettierrc.toml",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
  "prettier.config.ts",
}

local eslint_configs = {
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  ".eslintrc.json",
}

local biome_configs = {
  "biome.json",
  "biome.jsonc",
}

---@param patterns string[]
---@param dir string
---@return boolean
local function has_config(patterns, dir)
  return vim.fs.find(patterns, {
    upward = true,
    path = dir,
    stop = vim.env.HOME,
  })[1] ~= nil
end

return {
  -- Formatters: Prettier > Biome (según config del proyecto)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        -- Code: Prettier > Biome
        vue = { "prettier", "biome", stop_after_first = true },
        typescript = { "prettier", "biome", stop_after_first = true },
        javascript = { "prettier", "biome", stop_after_first = true },
        typescriptreact = { "prettier", "biome", stop_after_first = true },
        javascriptreact = { "prettier", "biome", stop_after_first = true },
        -- Data/styles: Prettier > Biome
        json = { "prettier", "biome", stop_after_first = true },
        jsonc = { "prettier", "biome", stop_after_first = true },
        css = { "prettier", "biome", stop_after_first = true },
        -- Prettier only (Biome no soporta)
        html = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        scss = { "prettier" },
        graphql = { "prettier" },
      },
      formatters = {
        prettier = {
          condition = function(self, ctx)
            return has_config(prettier_configs, ctx.dirname)
          end,
        },
        biome = {
          condition = function(self, ctx)
            return has_config(biome_configs, ctx.dirname)
              and not has_config(prettier_configs, ctx.dirname)
              and not has_config(eslint_configs, ctx.dirname)
          end,
        },
      },
    },
  },
}
