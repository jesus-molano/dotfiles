return {
  -- Claude Code: integración principal via LazyVim extra
  -- El extra lazyvim.plugins.extras.ai.claudecode ya se habilita en lazyvim.json
  -- Aquí solo override de opts y keybinds
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      terminal = {
        split_side = "right",
        split_width_percentage = 0.35,
        provider = "snacks",
      },
      diff_opts = {
        open_in_new_tab = true,
        auto_close_on_accept = true,
        keep_terminal_focus = true,
      },
    },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file from tree",
        ft = { "NvimTree", "neo-tree", "oil" },
      },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },

  -- Deshabilitar Avante (usamos Claude Code)
  { "yetone/avante.nvim", enabled = false },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    opts = {
      heading = {
        icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
      },
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      sign = { enabled = false },
    },
  },
  { "HakonHarnes/img-clip.nvim", enabled = false },
  { "saghen/blink-cmp-avante", enabled = false },
}
