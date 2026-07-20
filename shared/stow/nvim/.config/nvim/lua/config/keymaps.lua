vim.keymap.set("n", "<localleader>e", ":MoltenEvaluateOperator<CR>", { desc = "Evaluate operator", silent = true })
vim.keymap.set("n", "<localleader>os", ":noautocmd MoltenEnterOutput<CR>", { desc = "Open output", silent = true })

local function toggle_diffview()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewOpen")
  else
    vim.cmd("DiffviewClose")
  end
end

vim.keymap.set("n", "<leader>d", toggle_diffview, { desc = "Toggle Diffview" })
vim.keymap.set("n", "<leader>в", toggle_diffview, { desc = "Toggle Diffview" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })
