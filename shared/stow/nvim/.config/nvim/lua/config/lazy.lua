local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazy_commit = "85c7ff3711b730b4030d03144f6db6375044ae82"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    return
  end
  out = vim.fn.system({ "git", "-C", lazypath, "checkout", lazy_commit })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to pin lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    return
  end
end

vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = { enabled = true, notify = false },
})
