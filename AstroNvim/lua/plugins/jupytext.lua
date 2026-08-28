---@type LazySpec
return {
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    init = function()
      local molten_root = vim.fn.expand "~/.vens/molten"
      if vim.fn.isdirectory(molten_root) == 0 then molten_root = vim.fn.expand "~/.venvs/molten" end
      local molten_bin = molten_root .. "/bin"
      if vim.fn.isdirectory(molten_bin) == 1 then
        vim.env.PATH = molten_bin .. ":" .. (vim.env.PATH or "")
      end
    end,
    config = function()
      require("jupytext").setup {
        style = "hydrogen",
        output_extension = "auto",
        force_ft = "python",
      }
    end,
  },
}
