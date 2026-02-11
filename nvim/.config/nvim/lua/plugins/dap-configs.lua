return {
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")

      -- Node.js adapter (for Nuxt server-side / Vite SSR)
      if not dap.adapters["pwa-node"] then
        dap.adapters["pwa-node"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "node",
            args = {
              require("mason-registry").get_package("js-debug-adapter"):get_install_path()
                .. "/js-debug/src/dapDebugServer.js",
              "${port}",
            },
          },
        }
      end

      -- Chrome adapter (for Vite client-side)
      if not dap.adapters["pwa-chrome"] then
        dap.adapters["pwa-chrome"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "node",
            args = {
              require("mason-registry").get_package("js-debug-adapter"):get_install_path()
                .. "/js-debug/src/dapDebugServer.js",
              "${port}",
            },
          },
        }
      end

      -- Shared configurations for JS/TS filetypes
      for _, lang in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact", "vue" }) do
        if not dap.configurations[lang] then
          dap.configurations[lang] = {}
        end

        -- Only add if not already configured by another plugin
        local dominated = {}
        for _, config in ipairs(dap.configurations[lang]) do
          dominated[config.name] = true
        end

        local configs = {
          {
            name = "Nuxt: dev server",
            type = "pwa-node",
            request = "launch",
            program = "${workspaceFolder}/node_modules/.bin/nuxi",
            args = { "dev" },
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
            skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          },
          {
            name = "Vite: dev server (Chrome)",
            type = "pwa-chrome",
            request = "launch",
            url = "http://localhost:5173",
            webRoot = "${workspaceFolder}/src",
            sourceMaps = true,
          },
          {
            name = "Node: attach to process",
            type = "pwa-node",
            request = "attach",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            skipFiles = { "<node_internals>/**", "**/node_modules/**" },
          },
          {
            name = "Node: launch current file",
            type = "pwa-node",
            request = "launch",
            program = "${file}",
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            skipFiles = { "<node_internals>/**" },
          },
        }

        for _, config in ipairs(configs) do
          if not dominated[config.name] then
            table.insert(dap.configurations[lang], config)
          end
        end
      end
    end,
  },
}
