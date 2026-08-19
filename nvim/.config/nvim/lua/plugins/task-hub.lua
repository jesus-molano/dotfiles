local task_errorformat = table.concat({
  "%f(%l\\,%c): %t%*[^:]: %m",
  "%f:%l:%c - %t%*[^:]: %m",
  "%f:%l:%c: %t%*[^:]: %m",
  "%f:%l: %t%*[^:]: %m",
  "%f:%l:%c: %m",
  "%f:%l: %m",
}, ",")

return {
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerOpen",
      "OverseerClose",
      "OverseerToggle",
      "OverseerRun",
      "OverseerShell",
      "OverseerTaskAction",
    },
    keys = {
      { "<leader>jr", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>jl", "<cmd>OverseerToggle!<cr>", desc = "Toggle task list" },
      { "<leader>ja", "<cmd>OverseerTaskAction<cr>", desc = "Task action" },
      { "<leader>js", "<cmd>OverseerShell<cr>", desc = "Run shell task" },
    },
    dependencies = { "mfussenegger/nvim-dap" },
    opts = {
      -- Enables preLaunchTask and postDebugTask from VS Code launch.json files.
      dap = true,
      output = {
        -- Keep machine-readable compiler output intact for quickfix and diagnostics.
        use_terminal = false,
        preserve_output = true,
      },
      task_list = {
        direction = "bottom",
        min_height = 8,
        max_height = 0.28,
      },
      component_aliases = {
        default = {
          "on_exit_set_status",
          {
            "on_output_quickfix",
            errorformat = task_errorformat,
            items_only = true,
            set_diagnostics = true,
            open_on_exit = "failure",
            open_height = 12,
          },
          "on_result_diagnostics",
          { "on_complete_notify", statuses = { "FAILURE" } },
          { "on_complete_dispose", timeout = 300, require_view = { "SUCCESS", "FAILURE" } },
        },
        default_vscode = {
          "default",
          "on_result_diagnostics",
        },
      },
      -- Built-in templates discover justfile, package.json, mise tasks and
      -- .vscode/tasks.json from the current file up to the project root.
      template_timeout_ms = 5000,
    },
  },
}
