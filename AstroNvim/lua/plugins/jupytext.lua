---@type LazySpec
return {
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    init = function()
      local molten_root = vim.fn.expand "~/.vens/molten"
      if vim.fn.isdirectory(molten_root) == 0 then molten_root = vim.fn.expand "~/.venvs/molten" end
      local molten_bin = molten_root .. "/bin"
      if vim.fn.isdirectory(molten_bin) == 1 and not string.find(vim.env.PATH or "", molten_bin, 1, true) then
        vim.env.PATH = molten_bin .. ":" .. (vim.env.PATH or "")
      end
    end,
    config = function()
      local ok, jupy = pcall(require, "jupytext")
      if not ok then return end

      -- Handle both jupytext.nvim APIs:
      -- - GCBallesteros: { style, output_extension, force_ft, ... }
      -- - goerz: { jupytext, format, update, autosync, ... }
      if type(jupy.opts) == "table" and jupy.opts.jupytext ~= nil then
        jupy.setup {
          jupytext = "jupytext",
          format = "py:percent",
          update = true,
          autosync = true,
        }
      else
        jupy.setup {
          style = "hydrogen",
          output_extension = "auto",
        }
      end
    end,
  },
}
