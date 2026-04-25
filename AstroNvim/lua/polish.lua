-- polish.lua: Runs last in the AstroNvim setup process.

-- Re-enable python3 provider (AstroNvim disables it by default)
vim.g.loaded_python3_provider = nil
-- Dynamically find and use the system/Nix python3 path that has pynvim installed
vim.g.python3_host_prog = vim.fn.exepath("python3")
