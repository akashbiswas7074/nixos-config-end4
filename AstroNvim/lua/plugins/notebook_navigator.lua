---@type LazySpec
return {
  {
    "GCBallesteros/NotebookNavigator.nvim",
    ft = { "python", "markdown", "quarto" },
    dependencies = {
      "benlubas/molten-nvim",
    },
    opts = {
      repl_provider = "molten",
      syntax_highlight = true,
      show_hydra_hint = false,
      activate_hydra_keys = nil,
    },
    config = function(_, opts)
      local nn = require "notebook-navigator"
      nn.setup(opts)

      vim.api.nvim_create_user_command("CellBelow", function() nn.add_cell_below() end, { desc = "Add notebook cell below" })
      vim.api.nvim_create_user_command("CellAbove", function() nn.add_cell_above() end, { desc = "Add notebook cell above" })
      vim.api.nvim_create_user_command("CellSplit", function() nn.split_cell() end, { desc = "Split notebook cell at cursor" })
      vim.api.nvim_create_user_command("CellRun", function() nn.run_cell() end, { desc = "Run current notebook cell" })
      vim.api.nvim_create_user_command("CellRunNext", function() nn.run_and_move() end, { desc = "Run cell and move next" })
    end,
    keys = {
      { "]n", function() require("notebook-navigator").move_cell "d" end, desc = "Notebook: next cell" },
      { "[n", function() require("notebook-navigator").move_cell "u" end, desc = "Notebook: previous cell" },
      { "<Leader>mn", function() require("notebook-navigator").run_and_move() end, desc = "Notebook: run and next" },
      { "<Leader>mR", function() require("notebook-navigator").run_all_cells() end, desc = "Notebook: run all cells" },
      { "<Leader>mB", function() require("notebook-navigator").run_cells_below() end, desc = "Notebook: run cells below" },
      { "<Leader>mS", function() require("notebook-navigator").split_cell() end, desc = "Notebook: split cell" },
      { "<Leader>ma", function() require("notebook-navigator").add_cell_below() end, desc = "Notebook: add cell below" },
      { "<Leader>mA", function() require("notebook-navigator").add_cell_above() end, desc = "Notebook: add cell above" },
    },
  },
}
