return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "work",
          path = "~/vaults/work",
        },
      },

      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
        template = "daily.md",
      },

      templates = {
        folder = "templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M",
      },

      completion = {
        blink = true,
        nvim_cmp = false,
        min_chars = 2,
      },

      picker = {
        name = "snacks",
      },

      preferred_link_style = "markdown",
      new_notes_location = "current_dir",
      legacy_commands = false,

      attachments = {
        folder = "attachments",
        img_name_func = function()
          return string.format("img-%s", os.date("%Y%m%d%H%M%S"))
        end,
      },

      ui = {
        enable = false, -- render-markdown.nvim handles this
      },
    },
    keys = function()
      -- Ensure buffer is modifiable before running obsidian commands that write
      local function obs(cmd)
        return function()
          if not vim.bo.modifiable then
            vim.cmd("enew")
          end
          vim.cmd("Obsidian " .. cmd)
        end
      end

      return {
        { "<leader>on", obs("new"), desc = "New note" },
        { "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Quick switch" },
        { "<leader>os", "<cmd>Obsidian search<cr>", desc = "Search vault" },
        { "<leader>od", obs("today"), desc = "Daily note" },
        { "<leader>oy", obs("yesterday"), desc = "Yesterday" },
        { "<leader>oT", obs("tomorrow"), desc = "Tomorrow" },
        { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
        { "<leader>ol", "<cmd>Obsidian links<cr>", desc = "Links" },
        { "<leader>oL", "<cmd>Obsidian link_new<cr>", mode = "v", desc = "Link selection" },
        { "<leader>ot", "<cmd>Obsidian template<cr>", desc = "Insert template" },
        { "<leader>op", "<cmd>Obsidian paste_img<cr>", desc = "Paste image" },
        { "<leader>or", "<cmd>Obsidian rename<cr>", desc = "Rename note" },
        { "gf", "<cmd>Obsidian follow_link<cr>", desc = "Follow link", ft = "markdown" },
      }
    end,
  },
}
