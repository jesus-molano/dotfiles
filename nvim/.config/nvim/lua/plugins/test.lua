return {
  -- Vitest adapter
  { "marilari88/neotest-vitest" },

  -- Adapter config (LazyVim test.core ya configura neotest core opts)
  {
    "nvim-neotest/neotest",
    opts = {
      -- Desactivar coverage en neotest: evita output confuso,
      -- reduce JSON de 540KB a ~2KB, y acelera ejecuciones
      run = {
        augment = function(_, args)
          args.extra_args = args.extra_args or {}
          table.insert(args.extra_args, "--coverage.enabled=false")
          return args
        end,
      },
      adapters = {
        ["neotest-vitest"] = {
          -- Excluir directorios irrelevantes para rendimiento
          filter_dir = function(name)
            return not vim.tbl_contains({
              "node_modules",
              ".git",
              "dist",
              "build",
              "coverage",
              ".nuxt",
              ".next",
              ".output",
              ".vite",
              ".turbo",
            }, name)
          end,

          -- Monorepo: ejecutar desde el package.json más cercano al test
          cwd = function(file)
            local dir = vim.fn.fnamemodify(file, ":h")
            local pkg = vim.fs.find("package.json", {
              upward = true,
              path = dir,
              stop = vim.env.HOME,
            })[1]
            return pkg and vim.fn.fnamemodify(pkg, ":h") or vim.uv.cwd()
          end,

          -- vitestCommand omitido intencionalmente:
          -- El adapter busca node_modules/.bin/vitest por archivo,
          -- más rápido que pnpm exec/npx y correcto en monorepos.
        },
      },
    },
  },
}
