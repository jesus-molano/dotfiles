return {
  -- Codex runs in its own terminal/worktree; Copilot remains completion-only.
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
