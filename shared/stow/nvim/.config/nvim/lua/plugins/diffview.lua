return {
  {
    "dlyongemallo/diffview.nvim",
    version = "*",
    cmd = "DiffviewOpen",
    opts = {
      enhanced_diff_hl = true,
      view = { default = { layout = "diff2_horizontal" } },
      file_panel = { listing_style = "tree", win_config = { position = "left", width = 35 } },
    },
  },
}
