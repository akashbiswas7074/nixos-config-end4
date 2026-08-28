---@type LazySpec
return {
  {
    "GCBallesteros/NotebookNavigator.nvim",
    ft = { "python", "markdown", "quarto", "ipynb" },
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
  },
}
