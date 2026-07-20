local function toggle_diffview()
  if next(require("diffview.lib").views) == nil then
    vim.cmd("DiffviewOpen")
  else
    vim.cmd("DiffviewClose")
  end
end

return {
  {
    "dlyongemallo/diffview.nvim",
    version = "*",
    cmd = "DiffviewOpen",
    keys = {
      { "<leader>d", toggle_diffview, desc = "Toggle Diffview" },
      { "<leader>в", toggle_diffview, desc = "Toggle Diffview" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = { default = { layout = "diff2_horizontal" } },
      file_panel = { listing_style = "tree", win_config = { position = "left", width = 35 } },
    },
  },
}
