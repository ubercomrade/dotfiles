vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"
vim.opt.conceallevel = 2
vim.opt.termguicolors = true

local python = vim.env.NVIM_PYTHON
if python and vim.fn.executable(python) == 1 then
  vim.g.python3_host_prog = python
end

vim.g.molten_auto_open_output = false
vim.g.molten_image_provider = "image.nvim"
vim.g.molten_wrap_output = true
vim.g.molten_virt_text_output = true
vim.g.molten_virt_lines_off_by_1 = true
