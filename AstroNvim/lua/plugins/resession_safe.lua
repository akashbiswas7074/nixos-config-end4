---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    opts = function(_, opts)
      opts.mappings = opts.mappings or {}
      opts.mappings.n = opts.mappings.n or {}
      opts.mappings.n["<Leader>Sl"] = {
        function()
          local ok, err = pcall(function() require("resession").load "Last Session" end)
          if not ok then
            local msg = tostring(err or "")
            if msg:find('Could not find session "Last Session"', 1, true) then
              vim.notify("No previous session found yet. Open some files and quit Neovim once to create it.", vim.log.levels.INFO)
            else
              vim.notify("Session load failed: " .. msg, vim.log.levels.ERROR)
            end
          end
        end,
        desc = "Load last session",
      }
    end,
  },
}
