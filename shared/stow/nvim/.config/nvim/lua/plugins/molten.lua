return {
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
  },
  {
    "3rd/image.nvim",
    opts = { backend = "kitty", max_width = 100, max_height = 12 },
  },
}
