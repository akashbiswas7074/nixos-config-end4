---@type LazySpec
return {
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    init = function()
      local molten_root = vim.fn.expand "~/.vens/molten"
      if vim.fn.isdirectory(molten_root) == 0 then molten_root = vim.fn.expand "~/.venvs/molten" end
      local jupyter_runtime = vim.fn.expand "~/.local/share/jupyter/runtime"
      if vim.fn.isdirectory(jupyter_runtime) == 0 then vim.fn.mkdir(jupyter_runtime, "p") end
      vim.env.JUPYTER_RUNTIME_DIR = jupyter_runtime
      vim.g.python3_host_prog = molten_root .. "/bin/python"
      vim.g.molten_image_provider = "none"
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      mappings = {
        n = {
          ["<Leader>mi"] = { "<Cmd>MoltenInit molten<CR>", desc = "Molten: Init molten kernel" },
          ["<Leader>mr"] = { "<Cmd>MoltenEvaluateOperator<CR>", desc = "Molten: Eval operator" },
          ["<Leader>ml"] = { "<Cmd>MoltenEvaluateLine<CR>", desc = "Molten: Eval line" },
          ["<Leader>mv"] = { "<Cmd>MoltenEvaluateVisual<CR>", desc = "Molten: Eval visual" },
          ["<Leader>mc"] = { "<Cmd>MoltenReevaluateCell<CR>", desc = "Molten: Re-run cell" },
          ["<Leader>mo"] = { "<Cmd>noautocmd MoltenEnterOutput<CR>", desc = "Molten: Open output window" },
          ["<Leader>mh"] = { "<Cmd>MoltenHideOutput<CR>", desc = "Molten: Hide output" },
          ["<Leader>mx"] = { "<Cmd>MoltenInterrupt<CR>", desc = "Molten: Interrupt" },
          ["<Leader>md"] = { "<Cmd>MoltenDelete<CR>", desc = "Molten: Delete cell" },
          ["<Leader>mI"] = { "<Cmd>MoltenImportOutput<CR>", desc = "Molten: Import notebook output" },
          ["<Leader>mE"] = { "<Cmd>MoltenExportOutput!<CR>", desc = "Molten: Export notebook output" },
          -- Notebook Navigator Commands
          ["<Leader>mn"] = { function() require("notebook-navigator").run_and_move() end, desc = "Notebook: Run and next" },
          ["<Leader>mR"] = { function() require("notebook-navigator").run_all_cells() end, desc = "Notebook: Run all cells" },
          ["<Leader>mB"] = { function() require("notebook-navigator").run_cells_below() end, desc = "Notebook: Run cells below" },
          ["<Leader>ma"] = { function() require("notebook-navigator").add_cell_below() end, desc = "Notebook: Add cell below" },
          ["<Leader>mA"] = { function() require("notebook-navigator").add_cell_above() end, desc = "Notebook: Add cell above" },
          ["]n"] = { function() require("notebook-navigator").move_cell "d" end, desc = "Notebook: Next cell" },
          ["[n"] = { function() require("notebook-navigator").move_cell "u" end, desc = "Notebook: Previous cell" },
        },
        v = {
          ["<Leader>mv"] = { "<Cmd>MoltenEvaluateVisual<CR>", desc = "Molten: Eval visual" },
        },
      },
    },
  },
}
